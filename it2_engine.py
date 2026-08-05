"""
it2_engine.py
Interval Type-2 Fuzzy Inference Engine (Nie-Tan + Karnik-Mendel).
Includes built-in XAI (rule trace, membership intervals, explanation).
"""

import numpy as np
from typing import Dict, List, Tuple


class IT2FacultyEvaluator:
    """Hierarchical IT2 Fuzzy System with NT crisp output and KM interval."""

    def __init__(self, delta: int = 6):
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

    def _build_mfs(self):
        bases = {'Low': [0,0,25,45], 'Moderate': [25,45,45,65],
                 'High': [45,65,65,85], 'VeryHigh': [65,85,100,100]}
        mf_set = {}
        for name, (a,b,c,d) in bases.items():
            dom_l, dom_h = self.domain
            umf = [max(a-self.delta,dom_l), max(b-self.delta,dom_l),
                   min(c+self.delta,dom_h), min(d+self.delta,dom_h)]
            lb=b+self.delta; lc=c-self.delta
            if lb>lc: mid=(b+c)/2; lb=mid; lc=mid
            la=a+self.delta; ld=d-self.delta
            if la>lb: la=lb
            if ld<lc: ld=lc
            mf_set[name] = {'umf': np.array(umf), 'lmf': np.array([la,lb,lc,ld])}
        return mf_set

    @staticmethod
    def _trapmf(x, p):
        a,b,c,d = p
        if x<=a or x>=d: return 0.0
        if b<=x<=c: return 1.0
        if a<x<b: return (x-a)/(b-a)
        return (d-x)/(d-c)

    def _it2mf(self, x, umf, lmf):
        muU = self._trapmf(x, umf)
        muL = self._trapmf(x, lmf)
        return muL, muU

    def fuzzify(self, x):
        return {n: [round(self._trapmf(x, self.mf_set[n]['lmf']),4),
                    round(self._trapmf(x, self.mf_set[n]['umf']),4)]
                for n in self.term_names}

    @staticmethod
    def _monotonic_consequent(iv, w, nl, im):
        wavg = np.sum(iv * w)
        if im: scaled = 1 + (wavg - 1) / 3 * (nl - 1)
        else: scaled = wavg
        return max(1, min(int(np.round(scaled)), nl))

    def _build_rules(self, w, nl, im):
        rules = []
        for i1 in range(1,5):
            for i2 in range(1,5):
                for i3 in range(1,5):
                    out = self._monotonic_consequent(np.array([i1,i2,i3]), np.array(w), nl, im)
                    rules.append([i1,i2,i3,out])
        return np.array(rules, dtype=int)

    def _infer_nt(self, x1, x2, x3, rt, oc):
        R = rt.shape[0]; fL=np.zeros(R); fU=np.zeros(R); y=np.zeros(R)
        for r in range(R):
            i1,i2,i3,oi = rt[r]
            mL1,mU1 = self._it2mf(x1, self.mf_set[self.term_names[i1-1]]['umf'], self.mf_set[self.term_names[i1-1]]['lmf'])
            mL2,mU2 = self._it2mf(x2, self.mf_set[self.term_names[i2-1]]['umf'], self.mf_set[self.term_names[i2-1]]['lmf'])
            mL3,mU3 = self._it2mf(x3, self.mf_set[self.term_names[i3-1]]['umf'], self.mf_set[self.term_names[i3-1]]['lmf'])
            fL[r]=mL1*mL2*mL3; fU[r]=mU1*mU2*mU3; y[r]=oc[oi-1]
        if np.all(fU==0): return out_const[0], np.array([])
        fNT=(fL+fU)/2; yc=np.sum(fNT*y)/np.sum(fNT)
        active=fNT>0
        trace=np.column_stack([np.where(active)[0]+1, fL[active], fU[active], fNT[active], y[active]])
        return yc, trace

    def _infer_km(self, x1, x2, x3, rt, oc):
        R=rt.shape[0]; fL=np.zeros(R); fU=np.zeros(R); y=np.zeros(R)
        for r in range(R):
            i1,i2,i3,oi=rt[r]
            mL1,mU1=self._it2mf(x1,self.mf_set[self.term_names[i1-1]]['umf'],self.mf_set[self.term_names[i1-1]]['lmf'])
            mL2,mU2=self._it2mf(x2,self.mf_set[self.term_names[i2-1]]['umf'],self.mf_set[self.term_names[i2-1]]['lmf'])
            mL3,mU3=self._it2mf(x3,self.mf_set[self.term_names[i3-1]]['umf'],self.mf_set[self.term_names[i3-1]]['lmf'])
            fL[r]=mL1*mL2*mL3; fU[r]=mU1*mU2*mU3; y[r]=oc[oi-1]
        if np.all(fU==0):
            val = out_const[0]
            return val, val, val, np.array([])
        yL=self._km(y,fL,fU,'L'); yR=self._km(y,fL,fU,'R')
        yc=(yL+yR)/2
        fNT=(fL+fU)/2; active=fNT>0
        trace=np.column_stack([np.where(active)[0]+1, fL[active], fU[active], fNT[active], y[active]])
        return yc, yL, yR, trace

    @staticmethod
    def _km(y, fL, fU, side):
        order=np.argsort(y); ys=y[order]; fLs=fL[order]; fUs=fU[order]
        R=len(ys); f=(fLs+fUs)/2; d=np.sum(f)
        if d==0: return np.mean(ys)
        yp=np.sum(f*ys)/d
        for _ in range(200):
            k=np.searchsorted(ys,yp,side='right')-1; k=max(0,min(k,R-1))
            if side=='L': fn=np.concatenate([fUs[:k+1],fLs[k+1:]])
            else: fn=np.concatenate([fLs[:k+1],fUs[k+1:]])
            dn=np.sum(fn)
            if dn==0: break
            yn=np.sum(fn*ys)/dn
            if abs(yn-yp)<1e-12: yp=yn; break
            yp=yn
        return yp

    @staticmethod
    def _crisp_to_label(v, c, l):
        return l[np.argmin(np.abs(np.array(c)-v))]

    def _format_trace(self, trace, rt, oc, tn):
        if trace.size==0: return []
        order=np.argsort(trace[:,3])[::-1]; trace=trace[order]
        rules=[]
        for row in trace:
            ri=int(row[0])-1; ants=[tn[i-1] for i in rt[ri,:3]]
            rules.append({'rule_index':int(row[0]),'antecedents':ants,
                          'fL':round(float(row[1]),4),'fU':round(float(row[2]),4),
                          'fNT':round(float(row[3]),4),'consequent':round(float(row[4]),2)})
        return rules

    def _build_explanation(self, ts, tl, pg, pl, yL, yR, s1r, s2r):
        w=abs(yR-yL)
        lines=["="*60,"FACULTY EVALUATION — IT2 (INTERVAL TYPE-2)","="*60,"",
               f"📚 STAGE 1: Teaching Score = {ts:.1f} ({tl})"]
        if s1r:
            t=s1r[0]
            lines.append(f"   Top rule: IF AM={t['antecedents'][0]}, SEP={t['antecedents'][1]}, CL={t['antecedents'][2]}")
            lines.append(f"            → {t['consequent']:.0f} (fNT={t['fNT']:.3f})")
        lines.extend(["",f"🎓 STAGE 2: Performance Grade = {pg:.1f} ({pl})",
                      f"   Uncertainty interval: [{yL:.1f}, {yR:.1f}]"])
        if s2r:
            t=s2r[0]
            lines.append(f"   Top rule: IF Teach={t['antecedents'][0]}, AC={t['antecedents'][1]}, RC={t['antecedents'][2]}")
            lines.append(f"            → {t['consequent']:.0f} (fNT={t['fNT']:.3f})")
        lines.extend(["",f"📊 SUMMARY: Interval width = {w:.1f} points",
                      f"   Confidence: {'High' if w<10 else 'Moderate' if w<20 else 'Low'}","="*60])
        return "\n".join(lines)

    def evaluate(self, AM, SEP, CL, AC, RC):
        AM=float(AM); SEP=float(SEP); CL=float(CL); AC=float(AC); RC=float(RC)
        ts,t1=self._infer_nt(AM,SEP,CL,self.rule_teach,self.teach_out)
        tl=self._crisp_to_label(ts,self.teach_out,self.teach_labels)
        pg,yL,yR,t2=self._infer_km(ts,AC,RC,self.rule_master,self.master_out)
        pl=self._crisp_to_label(pg,self.master_out,self.master_labels)
        mems={k:self.fuzzify(v) for k,v in zip(['AM','SEP','CL','AC','RC'],[AM,SEP,CL,AC,RC])}
        s1r=self._format_trace(t1,self.rule_teach,self.teach_out,self.term_names)
        s2r=self._format_trace(t2,self.rule_master,self.master_out,self.term_names)
        expl=self._build_explanation(ts,tl,pg,pl,yL,yR,s1r,s2r)
        return {'TeachingScore':round(ts,2),'TeachingLabel':tl,
                'PerformanceGrade':round(pg,2),'PerformanceLabel':pl,
                'Interval':[round(yL,2),round(yR,2)],
                'Stage1_Rules':s1r,'Stage2_Rules':s2r,
                'Memberships':mems,'Explanation':expl}


if __name__=="__main__":
    e=IT2FacultyEvaluator(delta=6)
    r=e.evaluate(72,58,85,60,90)
    print(r['Explanation'])
