"""
it1_engine.py
Type-1 Sugeno Fuzzy Inference Engine for Faculty Performance Evaluation.

Hierarchical two-stage FIS -- the Type-1 baseline in the IT1-vs-IT2
comparison:
    Stage 1: AM, SEP, CL             -> Teaching Score
    Stage 2: Teaching Score, AC, RC  -> Performance Grade

KPIs (0-100 scale): AM = Academic Management, SEP = Student Examination
Performance, CL = Continuous Learning, AC = Activity Coordination,
RC = Research Contribution.

Rule base: 4 linguistic terms per antecedent, fully enumerated
(4^3 = 64 rules per stage, 128 total). Production-ready with input
validation and a built-in rule-trace explanation (XAI).
"""

import math
import warnings
from typing import Dict, List, Tuple

import numpy as np


class IT1FacultyEvaluator:
    """Hierarchical Type‑1 Sugeno Fuzzy System for Faculty Evaluation."""

    KPI_NAMES: Tuple[str, ...] = ('AM', 'SEP', 'CL', 'AC', 'RC')

    def __init__(self, warn_on_clip: bool = True):
        """
        Args:
            warn_on_clip: If True (default), warn whenever an input KPI
                falls outside [0, 100] and gets clipped. Set False for
                bulk/Monte Carlo runs (e.g. noise-robustness sweeps) where
                out-of-domain samples are expected and a warning per
                sample would just be noise.
        """
        self.domain = (0, 100)
        self.warn_on_clip = warn_on_clip
        self.mf_params = {
            'Low':       [0,   0,  25,  45],
            'Moderate':  [25, 45,  45,  65],
            'High':      [45, 65,  65,  85],
            'VeryHigh':  [65, 85, 100, 100]
        }
        self.term_names = ['Low', 'Moderate', 'High', 'VeryHigh']
        self.teach_out = [20, 45, 65, 85]
        self.master_out = [25, 50, 67, 83, 95]
        self.teach_labels = ['Low', 'Moderate', 'High', 'VeryHigh']
        self.master_labels = ['Poor', 'Fair', 'Good', 'VeryGood', 'Excellent']

        self.rule_teach = self._build_rule_table(
            weights=[1/3, 1/3, 1/3], num_out=4, is_master=False
        )
        self.rule_master = self._build_rule_table(
            weights=[0.25, 0.25, 0.50], num_out=5, is_master=True
        )

    def _membership(self, x: float, params: List[float]) -> float:
        """
        Trapezoidal membership, boundary-safe.
        Checks flat top (b<=x<=c) BEFORE the outside test (x<=a or x>=d).
        This matters for shoulder MFs where a==b or c==d.
        """
        a, b, c, d = params
        if b <= x <= c:
            return 1.0
        if x <= a or x >= d:
            return 0.0
        if a < x < b:
            return (x - a) / (b - a)
        if c < x < d:
            return (d - x) / (d - c)
        return 0.0

    def fuzzify(self, x: float) -> Dict[str, float]:
        """Public: membership of x in each of the 4 linguistic terms."""
        return {
            name: round(self._membership(x, params), 4)
            for name, params in self.mf_params.items()
        }

    def _term_memberships(self, x: float) -> np.ndarray:
        """Membership of x in each term, as an array ordered like term_names.
        Internal fast path for _infer: same math as fuzzify(), unrounded,
        computed once per input instead of once per rule."""
        return np.array([self._membership(x, self.mf_params[t]) for t in self.term_names])

    def _validate_input(self, value: float, name: str) -> float:
        """
        Coerce to float, reject non-finite values, and clip to the KPI
        domain. Without this, an out-of-domain or NaN value silently
        drives every rule's firing strength to zero, and _infer() falls
        back to a constant (the mean output level) instead of a value
        grounded in the rule base.
        """
        value = float(value)
        if not np.isfinite(value):
            raise ValueError(f"{name}={value!r} is not a finite number.")
        lo, hi = self.domain
        if value < lo or value > hi:
            clipped = min(max(value, lo), hi)
            if self.warn_on_clip:
                warnings.warn(
                    f"{name}={value:.2f} is outside the KPI domain {self.domain}; "
                    f"clipped to {clipped:.2f}.",
                    stacklevel=3,
                )
            value = clipped
        return value

    @staticmethod
    def _monotonic_consequent(idx_vec: np.ndarray, weights: np.ndarray,
                               num_levels: int, is_master: bool) -> int:
        """
        Maps a weighted average of antecedent term-indices (1..4) to a
        consequent term-index (1..num_levels).

        Uses standard round-half-up rather than numpy's round-half-to-even,
        so the rule table doesn't silently depend on rounding convention.
        (Verified against the current weights: this changes 0 of the 128
        rule consequents today -- no rule lands on an exact .5 boundary --
        but it removes that fragility if weights or level counts change.)
        """
        wavg = np.sum(idx_vec * weights)
        if is_master:
            scaled = 1 + (wavg - 1) / 3 * (num_levels - 1)
        else:
            scaled = wavg
        level = math.floor(scaled + 0.5)
        return int(max(1, min(level, num_levels)))

    def _build_rule_table(self, weights: List[float], num_out: int, is_master: bool) -> np.ndarray:
        """Fully enumerate the 4x4x4 = 64-rule table for one stage."""
        rules = []
        w = np.array(weights)
        for i1 in range(1, 5):
            for i2 in range(1, 5):
                for i3 in range(1, 5):
                    out = self._monotonic_consequent(np.array([i1,i2,i3]), w, num_out, is_master)
                    rules.append([i1, i2, i3, out])
        return np.array(rules, dtype=int)

    def _infer(self, x1: float, x2: float, x3: float,
               rule_table: np.ndarray, out_const: List[float]) -> Tuple[float, np.ndarray]:
        """
        Sugeno inference over a fully-enumerated rule table.

        Vectorized: membership is computed once per input (4 values each)
        and gathered across all 64 rules via fancy indexing, instead of
        recomputing membership per-rule inside a Python loop. Same result,
        ~16x fewer membership evaluations per call and no per-rule
        Python-level loop.
        """
        mu1 = self._term_memberships(x1)
        mu2 = self._term_memberships(x2)
        mu3 = self._term_memberships(x3)

        i1, i2, i3, oi = rule_table[:, 0], rule_table[:, 1], rule_table[:, 2], rule_table[:, 3]
        firing = mu1[i1 - 1] * mu2[i2 - 1] * mu3[i3 - 1]
        y_vals = np.asarray(out_const, dtype=float)[oi - 1]

        total_firing = firing.sum()
        if total_firing == 0:
            # Reachable only if inputs bypass evaluate()'s clipping and
            # land entirely outside the domain.
            return float(np.mean(out_const)), np.empty((0, 3))

        y_crisp = float(np.sum(firing * y_vals) / total_firing)
        active = firing > 0
        trace = np.column_stack([np.where(active)[0] + 1, firing[active], y_vals[active]])
        return y_crisp, trace

    @staticmethod
    def _crisp_to_label(value: float, centers: List[float], labels: List[str]) -> str:
        """Nearest-center label for a crisp output value."""
        return labels[np.argmin(np.abs(np.array(centers) - value))]

    def _format_trace(self, trace: np.ndarray, rule_table: np.ndarray,
                       out_const: List[float], term_names: List[str]) -> List[Dict]:
        """Turn a raw (rule_idx, firing, consequent) trace into a
        firing-strength-sorted list for the explanation / XAI output."""
        if trace.size == 0:
            return []
        order = np.argsort(trace[:, 1])[::-1]
        trace = trace[order]
        rules = []
        for row in trace:
            ri = int(row[0]) - 1
            ants = [term_names[i-1] for i in rule_table[ri, :3]]
            rules.append({
                'rule_index': int(row[0]),
                'antecedents': ants,
                'firing_strength': round(float(row[1]), 4),
                'consequent': round(float(row[2]), 2)
            })
        return rules

    def _build_explanation(self, ts: float, tl: str, pg: float, pl: str,
                            s1r: List[Dict], s2r: List[Dict]) -> str:
        lines = ["=" * 60, "FACULTY EVALUATION — IT1 (TYPE‑1)", "=" * 60, "",
                 f"📚 STAGE 1: Teaching Score = {ts:.1f} ({tl})"]
        if s1r:
            top = s1r[0]
            lines.append(f"   Top rule: IF AM={top['antecedents'][0]}, SEP={top['antecedents'][1]}, CL={top['antecedents'][2]}")
            lines.append(f"            → {top['consequent']:.0f} (μ={top['firing_strength']:.3f})")
        lines.extend(["", f"🎓 STAGE 2: Performance Grade = {pg:.1f} ({pl})",
                      "   Note: IT1 provides no uncertainty interval."])
        if s2r:
            top = s2r[0]
            lines.append(f"   Top rule: IF Teach={top['antecedents'][0]}, AC={top['antecedents'][1]}, RC={top['antecedents'][2]}")
            lines.append(f"            → {top['consequent']:.0f} (μ={top['firing_strength']:.3f})")
            max_mu = max(r['firing_strength'] for r in s2r)
            if max_mu > 0.7:
                conf = "High"
            elif max_mu > 0.4:
                conf = "Moderate"
            else:
                conf = "Low"
            lines.append(f"   Confidence (max rule strength): {conf} (μ_max = {max_mu:.3f})")
        lines.append("=" * 60)
        return "\n".join(lines)

    def evaluate(self, AM: float, SEP: float, CL: float, AC: float, RC: float) -> Dict:
        """
        Evaluate one faculty profile.

        KPIs are 0-100 (see module docstring for what each stands for).
        Out-of-domain values are clipped into range (see warn_on_clip);
        non-finite values (NaN/inf) raise ValueError.
        """
        AM, SEP, CL, AC, RC = [
            self._validate_input(v, n) for v, n in zip((AM, SEP, CL, AC, RC), self.KPI_NAMES)
        ]
        ts, t1 = self._infer(AM, SEP, CL, self.rule_teach, self.teach_out)
        tl = self._crisp_to_label(ts, self.teach_out, self.teach_labels)
        pg, t2 = self._infer(ts, AC, RC, self.rule_master, self.master_out)
        pl = self._crisp_to_label(pg, self.master_out, self.master_labels)
        mems = {k: self.fuzzify(v) for k, v in zip(self.KPI_NAMES, [AM, SEP, CL, AC, RC])}
        s1r = self._format_trace(t1, self.rule_teach, self.teach_out, self.term_names)
        s2r = self._format_trace(t2, self.rule_master, self.master_out, self.term_names)
        expl = self._build_explanation(ts, tl, pg, pl, s1r, s2r)
        return {
            'TeachingScore': round(ts, 2),
            'TeachingLabel': tl,
            'PerformanceGrade': round(pg, 2),
            'PerformanceLabel': pl,
            'Stage1_Rules': s1r,
            'Stage2_Rules': s2r,
            'Memberships': mems,
            'Explanation': expl
        }

    def __repr__(self) -> str:
        return (f"IT1FacultyEvaluator(domain={self.domain}, "
                f"rules={len(self.rule_teach)}+{len(self.rule_master)}, "
                f"warn_on_clip={self.warn_on_clip})")


if __name__ == "__main__":
    evaluator = IT1FacultyEvaluator()
    result = evaluator.evaluate(AM=80, SEP=70, CL=90, AC=60, RC=75)
    print(result['Explanation'])