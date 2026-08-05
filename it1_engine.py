"""
it1_engine.py
Type‑1 Sugeno Fuzzy Inference Engine for Faculty Performance Evaluation.
Includes built‑in XAI (rule trace, membership breakdown, natural‑language explanation)
with a confidence indicator based on maximum rule activation strength.
"""

import numpy as np
from typing import Dict, List, Tuple


class IT1FacultyEvaluator:
    """Hierarchical Type‑1 Sugeno Fuzzy System for Faculty Evaluation."""

    def __init__(self):
        self.domain = (0, 100)
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

        # Build rule tables (monotonic expert consequent)
        self.rule_teach = self._build_rule_table(
            weights=[1/3, 1/3, 1/3], num_output_levels=4, is_master=False
        )
        self.rule_master = self._build_rule_table(
            weights=[0.25, 0.25, 0.50], num_output_levels=5, is_master=True
        )

    # =====================================================================
    # MEMBERSHIP FUNCTIONS
    # =====================================================================

    def _membership(self, x: float, params: List[float]) -> float:
        """Trapezoidal / triangular membership function."""
        a, b, c, d = params
        if x <= a or x >= d:
            return 0.0
        if b <= x <= c:
            return 1.0
        if a < x < b:
            return (x - a) / (b - a)
        if c < x < d:
            return (d - x) / (d - c)
        return 0.0

    def fuzzify(self, x: float) -> Dict[str, float]:
        """Fuzzify a single input: return membership in all 4 terms."""
        return {
            name: round(self._membership(x, params), 4)
            for name, params in self.mf_params.items()
        }

    # =====================================================================
    # RULE TABLE CONSTRUCTION (monotonic)
    # =====================================================================

    @staticmethod
    def _monotonic_consequent(idx_vec: np.ndarray, weights: np.ndarray,
                              num_levels: int, is_master: bool) -> int:
        """Monotonic rule consequent: weighted average -> round -> clamp."""
        wavg = np.sum(idx_vec * weights)
        if is_master:
            scaled = 1 + (wavg - 1) / 3 * (num_levels - 1)
        else:
            scaled = wavg
        out_idx = int(np.round(scaled))
        return max(1, min(out_idx, num_levels))

    def _build_rule_table(self, weights: List[float],
                          num_output_levels: int,
                          is_master: bool) -> np.ndarray:
        """Build complete rule table by enumerating all 4^3 = 64 combinations."""
        rules = []
        w = np.array(weights)
        for i1 in range(1, 5):
            for i2 in range(1, 5):
                for i3 in range(1, 5):
                    idx_vec = np.array([i1, i2, i3])
                    out_idx = self._monotonic_consequent(
                        idx_vec, w, num_output_levels, is_master
                    )
                    rules.append([i1, i2, i3, out_idx])
        return np.array(rules, dtype=int)

    # =====================================================================
    # INFERENCE ENGINE
    # =====================================================================

    def _infer_stage(self, x1: float, x2: float, x3: float,
                     rule_table: np.ndarray, out_const: List[float]
                     ) -> Tuple[float, np.ndarray]:
        """Sugeno inference with rule trace."""
        R = rule_table.shape[0]
        firing = np.zeros(R)
        y_vals = np.zeros(R)

        for r in range(R):
            i1, i2, i3, out_idx = rule_table[r]
            mu1 = self._membership(x1, self.mf_params[self.term_names[i1-1]])
            mu2 = self._membership(x2, self.mf_params[self.term_names[i2-1]])
            mu3 = self._membership(x3, self.mf_params[self.term_names[i3-1]])
            firing[r] = mu1 * mu2 * mu3
            y_vals[r] = out_const[out_idx - 1]

        if np.sum(firing) == 0:
            return out_const[0], np.array([])
        

        y_crisp = np.sum(firing * y_vals) / np.sum(firing)

        # Build trace: only active rules
        active = firing > 0
        trace = np.column_stack([
            np.where(active)[0] + 1,  # 1‑based rule index
            firing[active],
            y_vals[active]
        ])
        return y_crisp, trace

    # =====================================================================
    # HELPER METHODS
    # =====================================================================

    @staticmethod
    def _crisp_to_label(value: float, centers: List[float],
                        labels: List[str]) -> str:
        """Map a crisp value to the nearest linguistic label."""
        idx = np.argmin(np.abs(np.array(centers) - value))
        return labels[idx]

    def _format_trace(self, trace: np.ndarray, rule_table: np.ndarray,
                      out_const: List[float], term_names: List[str]) -> List[Dict]:
        """Format a rule trace array into a list of dictionaries."""
        if trace.size == 0:
            return []

        # Sort by firing strength descending
        order = np.argsort(trace[:, 1])[::-1]
        trace = trace[order]

        rules = []
        for row in trace:
            rule_idx = int(row[0]) - 1  # convert to 0‑based index
            antecedents = rule_table[rule_idx, :3]
            antecedents_str = [term_names[i-1] for i in antecedents]
            rules.append({
                'rule_index': int(row[0]),
                'antecedents': antecedents_str,
                'firing_strength': round(float(row[1]), 4),
                'consequent': round(float(row[2]), 2)
            })
        return rules

    def _build_explanation(self, teach_score: float, teach_label: str,
                           perf_grade: float, perf_label: str,
                           stage1_rules: List[Dict],
                           stage2_rules: List[Dict]) -> str:
        """Build a natural‑language explanation with confidence indicator."""
        lines = []
        lines.append("=" * 60)
        lines.append("FACULTY EVALUATION — IT1 (TYPE‑1)")
        lines.append("=" * 60)
        lines.append("")

        # Stage 1
        lines.append(f"📚 STAGE 1: Teaching Score = {teach_score:.1f} ({teach_label})")
        if stage1_rules:
            top = stage1_rules[0]
            lines.append(f"   Top rule: IF AM is {top['antecedents'][0]}, "
                         f"SEP is {top['antecedents'][1]}, "
                         f"CL is {top['antecedents'][2]}")
            lines.append(f"            THEN TeachingScore = {top['consequent']:.0f} "
                         f"(strength: {top['firing_strength']:.3f})")
        lines.append("")

        # Stage 2
        lines.append(f"🎓 STAGE 2: Performance Grade = {perf_grade:.1f} ({perf_label})")
        lines.append("   Note: IT1 does not provide an uncertainty interval.")
        if stage2_rules:
            top = stage2_rules[0]
            lines.append(f"   Top rule: IF TeachingScore is {top['antecedents'][0]}, "
                         f"AC is {top['antecedents'][1]}, "
                         f"RC is {top['antecedents'][2]}")
            lines.append(f"            THEN PerformanceGrade = {top['consequent']:.0f} "
                         f"(strength: {top['firing_strength']:.3f})")

            # --- Confidence based on max firing strength ---
            max_strength = max(r['firing_strength'] for r in stage2_rules)
            if max_strength > 0.7:
                conf = "High"
            elif max_strength > 0.4:
                conf = "Moderate"
            else:
                conf = "Low"
            lines.append(f"   Confidence (max rule strength): {conf} (μ_max = {max_strength:.3f})")

        lines.append("=" * 60)
        return "\n".join(lines)

    # =====================================================================
    # MAIN EVALUATION METHOD
    # =====================================================================

    def evaluate(self, AM: float, SEP: float, CL: float,
                 AC: float, RC: float) -> Dict:
        """
        Evaluate a single faculty profile and return complete results with XAI.
        """
        AM = float(AM)
        SEP = float(SEP)
        CL = float(CL)
        AC = float(AC)
        RC = float(RC)

        # Stage 1: TeachingScore
        teach_score, trace1 = self._infer_stage(
            AM, SEP, CL, self.rule_teach, self.teach_out
        )
        teach_label = self._crisp_to_label(teach_score, self.teach_out, self.teach_labels)

        # Stage 2: PerformanceGrade
        perf_grade, trace2 = self._infer_stage(
            teach_score, AC, RC, self.rule_master, self.master_out
        )
        perf_label = self._crisp_to_label(perf_grade, self.master_out, self.master_labels)

        # Fuzzify all inputs
        memberships = {
            'AM':  self.fuzzify(AM),
            'SEP': self.fuzzify(SEP),
            'CL':  self.fuzzify(CL),
            'AC':  self.fuzzify(AC),
            'RC':  self.fuzzify(RC)
        }

        # Format rule traces
        stage1_rules = self._format_trace(trace1, self.rule_teach,
                                          self.teach_out, self.term_names)
        stage2_rules = self._format_trace(trace2, self.rule_master,
                                          self.master_out, self.term_names)

        # Build explanation
        explanation = self._build_explanation(
            teach_score, teach_label, perf_grade, perf_label,
            stage1_rules, stage2_rules
        )

        return {
            'TeachingScore': round(teach_score, 2),
            'TeachingLabel': teach_label,
            'PerformanceGrade': round(perf_grade, 2),
            'PerformanceLabel': perf_label,
            'Stage1_Rules': stage1_rules,
            'Stage2_Rules': stage2_rules,
            'Memberships': memberships,
            'Explanation': explanation
        }


# =====================================================================
# SELF‑TEST (runs when file is executed directly)
# =====================================================================
if __name__ == "__main__":
    evaluator = IT1FacultyEvaluator()
    result = evaluator.evaluate(AM=72, SEP=58, CL=85, AC=60, RC=90)

    print(result['Explanation'])
    print(f"\nTeachingScore: {result['TeachingScore']} ({result['TeachingLabel']})")
    print(f"PerformanceGrade: {result['PerformanceGrade']} ({result['PerformanceLabel']})")
    print("\nSTAGE 1 FIRED RULES:")
    for r in result['Stage1_Rules']:
        print(f"  Rule {r['rule_index']:2d}: {r['antecedents']} "
              f"→ {r['consequent']:.0f} (μ={r['firing_strength']:.4f})")
    print("\nSTAGE 2 FIRED RULES:")
    for r in result['Stage2_Rules']:
        print(f"  Rule {r['rule_index']:2d}: {r['antecedents']} "
              f"→ {r['consequent']:.0f} (μ={r['firing_strength']:.4f})")
