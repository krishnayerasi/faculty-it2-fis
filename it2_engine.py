"""
it2_engine.py
Interval Type-2 Fuzzy Inference Engine (Nie-Tan + Karnik-Mendel).
Production-ready with robust edge-case handling and built-in XAI.

Changelog (this revision)
--------------------------
Two structural bugs fixed:

1. Boundary dead-zone in `_trapmf`. The original condition order checked
   `x <= a or x >= d` before the flat-top test `b <= x <= c`. For shoulder
   terms where a == b (Low's UMF always has a == b == 0) or c == d
   (VeryHigh's UMF always has c == d == 100), evaluating exactly at that
   boundary incorrectly returned 0.0 instead of 1.0 -- the most extreme,
   least ambiguous input (a raw score of exactly 0 or 100) scored as having
   NO membership in the term it should belong to most strongly. Fixed by
   checking the flat top first; this also removes any risk of dividing by
   zero on a degenerate rising/falling edge, since that branch becomes
   unreachable whenever its divisor would be zero.

2. LMF monotonicity violation in `_build_mfs` at high delta. Narrowing a
   trapezoid's core inward by `delta` on both sides can make the two inner
   parameters (b, c) cross once delta > (c-b)/2. The previous fix collapsed
   the crossed pair to (b+c)/2 using the *original*, un-shifted b and c,
   with no check that the result stayed inside the outer envelope
   [a+delta, d-delta] (which is itself always valid -- widening/narrowing
   by a constant preserves a<=b and c<=d unconditionally). Confirmed broken
   under the original logic at delta=12 (VeryHigh -> [77, 90.25, 88, 88],
   b>c) and delta=15 (Low -> [15, 13.75, 13.75, 30], a>b). Fixed by clamping
   the collapse point into the outer envelope, which is provably valid for
   every delta >= 0 (see docstring on `_build_mfs`), plus a final safety net
   for pathologically large delta where even the outer envelope inverts.

Run `python it2_engine.py` to execute the built-in regression checklist.
"""

import warnings
from typing import Any, Dict, List, Tuple

import numpy as np


class IT2FacultyEvaluator:
    """Hierarchical IT2 Fuzzy System with NT crisp output and KM interval."""

    def __init__(self, delta: int = 6):
        if delta < 0:
            raise ValueError(f"delta must be >= 0, got {delta}")
        self.delta = delta
        self.domain = (0, 100)
        self.term_names = ['Low', 'Moderate', 'High', 'VeryHigh']
        self.teach_out = [20, 45, 65, 85]
        self.master_out = [25, 50, 67, 83, 95]
        self.teach_labels = ['Low', 'Moderate', 'High', 'VeryHigh']
        self.master_labels = ['Poor', 'Fair', 'Good', 'VeryGood', 'Excellent']
        self.mf_set = self._build_mfs()
        self.rule_teach = self._build_rules([1/3, 1/3, 1/3], 4, False)
        self.rule_master = self._build_rules([0.25, 0.25, 0.50], 5, True)

    def _build_mfs(self) -> Dict[str, Dict[str, np.ndarray]]:
        """
        Build IT2 fuzzy sets via symmetric footprint-of-uncertainty (FOU).

        UMF = base trapezoid (a,b,c,d) widened outward by `delta`. Widening
        can never invert the parameter order: clamping to the domain is
        monotonic, and a<=b implies a-delta<=b-delta (same for c,d), so
        ua<=ub<=uc<=ud holds automatically -- no correction is ever needed.

        LMF = base trapezoid narrowed inward by `delta`. This CAN invert:
        if delta > (c-b)/2, the inward-shifted b and c cross. When that
        happens both collapse to their midpoint, clamped into the outer
        envelope [a+delta, d-delta]. That envelope is itself always valid
        (a+delta<=b+delta and c-delta<=d-delta hold unconditionally whenever
        a<=b<=c<=d), so clamping the collapse point into it guarantees
        la<=lb<=lc<=ld for every delta >= 0. A final check handles the
        (unrealistic, but possible for very large delta) case where even
        the outer envelope itself crosses.
        """
        bases = {
            'Low':       [0,   0,  25,  45],
            'Moderate':  [25, 45,  45,  65],
            'High':      [45, 65,  65,  85],
            'VeryHigh':  [65, 85, 100, 100],
        }
        dom_l, dom_h = self.domain

        def clamp(v: float) -> float:
            return max(dom_l, min(dom_h, v))

        mf_set = {}
        for name, (a, b, c, d) in bases.items():
            # UMF: widen outward -- always valid, no correction needed.
            ua = clamp(a - self.delta)
            ub = clamp(b - self.delta)
            uc = clamp(c + self.delta)
            ud = clamp(d + self.delta)

            # LMF: narrow inward.
            la = clamp(a + self.delta)
            lb = clamp(b + self.delta)
            lc = clamp(c - self.delta)
            ld = clamp(d - self.delta)
            if lb > lc:
                mid = (lb + lc) / 2
                mid = max(la, min(ld, mid))  # pin inside the outer envelope
                lb = lc = mid
            if la > ld:
                # Pathological delta: even the outer envelope crossed.
                la = lb = lc = ld = (la + ld) / 2

            mf_set[name] = {
                'umf': np.array([ua, ub, uc, ud], dtype=float),
                'lmf': np.array([la, lb, lc, ld], dtype=float),
            }
        return mf_set

    @staticmethod
    def _trapmf(x: float, p: np.ndarray) -> float:
        """
        Trapezoidal membership, boundary-safe.

        Checks the flat top (b<=x<=c) before the "outside" test (x<=a or
        x>=d). This matters whenever a==b or c==d (shoulder MFs): at
        x==a==b the flat-top region legitimately includes x, and checking
        "outside" first would wrongly zero it out. This ordering also makes
        the rising/falling branches below unreachable whenever their
        divisor would be zero, so no separate divide-by-zero guard is
        needed.
        """
        a, b, c, d = p
        if b <= x <= c:
            return 1.0
        if x <= a or x >= d:
            return 0.0
        if x < b:
            return (x - a) / (b - a)
        return (d - x) / (d - c)

    def _it2mf(self, x: float, umf: np.ndarray, lmf: np.ndarray) -> Tuple[float, float]:
        """Return (lower, upper) membership. Lower <= Upper always."""
        u = self._trapmf(x, umf)
        l = self._trapmf(x, lmf)
        if l > u:
            l = u
        return l, u

    def fuzzify(self, x: float) -> Dict[str, List[float]]:
        result = {}
        for n in self.term_names:
            l, u = self._it2mf(x, self.mf_set[n]['umf'], self.mf_set[n]['lmf'])
            result[n] = [round(l, 4), round(u, 4)]
        return result

    @staticmethod
    def _monotonic_consequent(iv: np.ndarray, w: np.ndarray, nl: int, im: bool) -> int:
        wavg = np.sum(iv * w)
        if im:
            scaled = 1 + (wavg - 1) / 3 * (nl - 1)
        else:
            scaled = wavg
        return max(1, min(int(np.round(scaled)), nl))

    def _build_rules(self, w: List[float], nl: int, im: bool) -> np.ndarray:
        n_terms = len(self.term_names)
        rules = []
        for i1 in range(1, n_terms + 1):
            for i2 in range(1, n_terms + 1):
                for i3 in range(1, n_terms + 1):
                    out = self._monotonic_consequent(
                        np.array([i1, i2, i3]), np.array(w), nl, im
                    )
                    rules.append([i1, i2, i3, out])
        return np.array(rules, dtype=int)

    def _fire_rules(self, x1: float, x2: float, x3: float,
                     rt: np.ndarray, outConst: List[float]
                     ) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """Compute (fL, fU, y) firing-strength arrays for every rule in rt.
        Shared by `_infer_nt` and `_infer_km` (previously duplicated)."""
        R = rt.shape[0]
        fL = np.zeros(R)
        fU = np.zeros(R)
        y = np.zeros(R)
        for r in range(R):
            i1, i2, i3, oi = rt[r]
            l1, u1 = self._it2mf(x1, self.mf_set[self.term_names[i1-1]]['umf'],
                                 self.mf_set[self.term_names[i1-1]]['lmf'])
            l2, u2 = self._it2mf(x2, self.mf_set[self.term_names[i2-1]]['umf'],
                                 self.mf_set[self.term_names[i2-1]]['lmf'])
            l3, u3 = self._it2mf(x3, self.mf_set[self.term_names[i3-1]]['umf'],
                                 self.mf_set[self.term_names[i3-1]]['lmf'])
            fL[r] = l1 * l2 * l3
            fU[r] = u1 * u2 * u3
            y[r] = outConst[oi - 1]
        return fL, fU, y

    @staticmethod
    def _make_trace(fL: np.ndarray, fU: np.ndarray, y: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        fNT = (fL + fU) / 2
        active = fNT > 0
        trace = np.column_stack([
            np.where(active)[0] + 1, fL[active], fU[active], fNT[active], y[active]
        ])
        return fNT, trace

    def _infer_nt(self, x1, x2, x3, rt, outConst):
        fL, fU, y = self._fire_rules(x1, x2, x3, rt, outConst)
        if not np.any(fU):
            return float(np.mean(outConst)), np.array([])
        fNT, trace = self._make_trace(fL, fU, y)
        yc = np.sum(fNT * y) / np.sum(fNT)
        return yc, trace

    def _infer_km(self, x1, x2, x3, rt, outConst):
        fL, fU, y = self._fire_rules(x1, x2, x3, rt, outConst)
        if not np.any(fU):
            mv = float(np.mean(outConst))
            return mv, mv, mv, np.array([])
        yL = self._km(y, fL, fU, 'L')
        yR = self._km(y, fL, fU, 'R')
        yc = (yL + yR) / 2
        fNT, trace = self._make_trace(fL, fU, y)
        return yc, yL, yR, trace

    @staticmethod
    def _km(y, fL, fU, side):
        order = np.argsort(y)
        ys = y[order]
        fLs = fL[order]
        fUs = fU[order]
        R = len(ys)
        f = (fLs + fUs) / 2
        d = np.sum(f)
        if d == 0:
            return np.mean(ys)
        yp = np.sum(f * ys) / d
        for _ in range(200):
            k = np.searchsorted(ys, yp, side='right') - 1
            k = max(0, min(k, R - 1))
            if side == 'L':
                fn = np.concatenate([fUs[:k+1], fLs[k+1:]])
            else:
                fn = np.concatenate([fLs[:k+1], fUs[k+1:]])
            dn = np.sum(fn)
            if dn == 0:
                break
            yn = np.sum(fn * ys) / dn
            if abs(yn - yp) < 1e-12:
                yp = yn
                break
            yp = yn
        return yp

    @staticmethod
    def _crisp_to_label(v, c, l):
        return l[np.argmin(np.abs(np.array(c) - v))]

    def _format_trace(self, trace, rt, oc, tn):
        if trace.size == 0:
            return []
        order = np.argsort(trace[:, 3])[::-1]
        trace = trace[order]
        rules = []
        for row in trace:
            ri = int(row[0]) - 1
            ants = [tn[i-1] for i in rt[ri, :3]]
            rules.append({
                'rule_index': int(row[0]),
                'antecedents': ants,
                'fL': round(float(row[1]), 4),
                'fU': round(float(row[2]), 4),
                'fNT': round(float(row[3]), 4),
                'consequent': round(float(row[4]), 2)
            })
        return rules

    def _build_explanation(self, ts, tl, pg, pl, yL, yR, s1r, s2r):
        w = abs(yR - yL)
        lines = ["=" * 60, "FACULTY EVALUATION — IT2 (INTERVAL TYPE-2)", "=" * 60, "",
                 f"📚 STAGE 1: Teaching Score = {ts:.1f} ({tl})"]
        if s1r:
            t = s1r[0]
            lines.append(
                f"   Top rule: IF AM={t['antecedents'][0]}, "
                f"SEP={t['antecedents'][1]}, CL={t['antecedents'][2]}"
            )
            lines.append(f"            → {t['consequent']:.0f} (fNT={t['fNT']:.3f})")
        lines.extend(["", f"🎓 STAGE 2: Performance Grade = {pg:.1f} ({pl})",
                      f"   Uncertainty interval: [{yL:.1f}, {yR:.1f}]"])
        if s2r:
            t = s2r[0]
            lines.append(
                f"   Top rule: IF Teach={t['antecedents'][0]}, "
                f"AC={t['antecedents'][1]}, RC={t['antecedents'][2]}"
            )
            lines.append(f"            → {t['consequent']:.0f} (fNT={t['fNT']:.3f})")
        lines.extend(["", f"📊 SUMMARY: Interval width = {w:.1f} points",
                      f"   Confidence: {'High' if w < 10 else 'Moderate' if w < 20 else 'Low'}",
                      "=" * 60])
        return "\n".join(lines)

    def evaluate(self, AM: float, SEP: float, CL: float, AC: float, RC: float) -> Dict[str, Any]:
        raw = {'AM': AM, 'SEP': SEP, 'CL': CL, 'AC': AC, 'RC': RC}
        clipped = []
        for name, v in raw.items():
            v = float(v)
            if np.isnan(v):
                raise ValueError(f"{name} is NaN.")
            c = min(max(v, self.domain[0]), self.domain[1])
            if c != v:
                clipped.append(f"{name}={v}->{c}")
            raw[name] = c
        if clipped:
            warnings.warn(f"Input(s) outside domain {self.domain} were clipped: " + ", ".join(clipped))
        AM, SEP, CL, AC, RC = raw['AM'], raw['SEP'], raw['CL'], raw['AC'], raw['RC']

        ts, t1 = self._infer_nt(AM, SEP, CL, self.rule_teach, self.teach_out)
        tl = self._crisp_to_label(ts, self.teach_out, self.teach_labels)
        pg, yL, yR, t2 = self._infer_km(ts, AC, RC, self.rule_master, self.master_out)
        pl = self._crisp_to_label(pg, self.master_out, self.master_labels)
        mems = {k: self.fuzzify(v) for k, v in zip(
            ['AM', 'SEP', 'CL', 'AC', 'RC'], [AM, SEP, CL, AC, RC]
        )}
        s1r = self._format_trace(t1, self.rule_teach, self.teach_out, self.term_names)
        s2r = self._format_trace(t2, self.rule_master, self.master_out, self.term_names)
        expl = self._build_explanation(ts, tl, pg, pl, yL, yR, s1r, s2r)
        return {
            'TeachingScore': round(ts, 2),
            'TeachingLabel': tl,
            'PerformanceGrade': round(pg, 2),
            'PerformanceLabel': pl,
            'Interval': [round(yL, 2), round(yR, 2)],
            'Stage1_Rules': s1r,
            'Stage2_Rules': s2r,
            'Memberships': mems,
            'Explanation': expl
        }


# -----------------------------------------------------------------------
# Regression checklist -- run `python it2_engine.py`
# -----------------------------------------------------------------------
def _find_first_lmf_violation(max_delta: int = 30):
    """Sweep delta and return the first (delta, term, kind, params) where
    a<=b<=c<=d fails, or None if no violation is found in the swept range."""
    for delta in range(0, max_delta + 1):
        ev = IT2FacultyEvaluator(delta=delta)
        for term, mf in ev.mf_set.items():
            for kind in ('umf', 'lmf'):
                p = mf[kind]
                if not (p[0] <= p[1] + 1e-9 and p[1] <= p[2] + 1e-9 and p[2] <= p[3] + 1e-9):
                    return (delta, term, kind, list(np.round(p, 3)))
    return None


def _run_self_tests() -> bool:
    """
    Regression checklist for the two structural bugs fixed in this revision:
      1. Boundary dead-zone in `_trapmf`.
      2. LMF monotonicity violations in `_build_mfs` at high delta
         (previously broken at delta=12 on 'VeryHigh' and delta=15 on 'Low').
    """
    all_ok = True

    def check(label: str, cond: bool) -> None:
        nonlocal all_ok
        print(f"  [{'PASS' if cond else 'FAIL'}] {label}")
        if not cond:
            all_ok = False

    print("=" * 60)
    print("IT2FacultyEvaluator -- regression checklist")
    print("=" * 60)

    print("\n1. Domain-boundary membership (shoulder MFs)")
    base = IT2FacultyEvaluator(delta=6)
    low_at_0 = base._trapmf(0.0, base.mf_set['Low']['umf'])
    vh_at_100 = base._trapmf(100.0, base.mf_set['VeryHigh']['umf'])
    check("Low.UMF(x=0) == 1.0  (was 0.0 before the fix)", abs(low_at_0 - 1.0) < 1e-9)
    check("VeryHigh.UMF(x=100) == 1.0  (was 0.0 before the fix)", abs(vh_at_100 - 1.0) < 1e-9)

    print("\n2. LMF/UMF parameter monotonicity, delta swept 0..30")
    failure = _find_first_lmf_violation(30)
    check("a<=b<=c<=d holds for every term at every delta"
          + ("" if failure is None else f"  (first failure: {failure})"),
          failure is None)

    print("\n3. Specific cases originally flagged as broken")
    p_vh = IT2FacultyEvaluator(delta=12).mf_set['VeryHigh']['lmf']
    check(f"delta=12  VeryHigh LMF = {list(np.round(p_vh, 3))}  valid",
          p_vh[0] <= p_vh[1] <= p_vh[2] <= p_vh[3])
    p_low = IT2FacultyEvaluator(delta=15).mf_set['Low']['lmf']
    check(f"delta=15  Low LMF = {list(np.round(p_low, 3))}  valid",
          p_low[0] <= p_low[1] <= p_low[2] <= p_low[3])

    print("\n4. End-to-end evaluate() smoke test")
    try:
        result = base.evaluate(80, 75, 70, 85, 60)
        check(f"evaluate() -> PerformanceGrade={result['PerformanceGrade']}, "
              f"Interval={result['Interval']}",
              np.isfinite(result['PerformanceGrade']))
    except Exception as exc:
        check(f"evaluate() raised {exc!r}", False)

    print("\n" + "=" * 60)
    print("RESULT:", "ALL CHECKS PASSED" if all_ok else "SOME CHECKS FAILED")
    print("=" * 60)
    return all_ok


if __name__ == "__main__":
    _run_self_tests()