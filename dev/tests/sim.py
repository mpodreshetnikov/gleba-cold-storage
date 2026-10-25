import math
def k_at(t,cap): return min(cap,max(0.5,2**((20-t)/12.6)))
def sim(amb,target,reach,ctau,wtau,cap,cooled_fn,dur=18000,P=60):
    T=amb; used=0
    for i in range(1,dur//P+1):
        c=cooled_fn(i*P)
        tg,tau=(max(target,amb-reach),ctau) if c else (amb,wtau)
        nt=tg+(T-tg)*math.exp(-P/(tau*60))
        k=(k_at(T,cap)+k_at(nt,cap))/2
        used+=P/k; T=nt
    return dur/used, T
on=lambda t: t>60
print("chamber", sim(15,0,25,60,300,3,on))
print("blocked(~35s)", sim(15,0,25,60,300,3,lambda t: 60<t<=2100))
print("dry", sim(15,0,25,60,300,3,lambda t: False))
print("vault", sim(15,-35,60,120,600,20,on))
print("vault 3600", sim(15,-35,60,120,600,20,on,dur=3600))
print("halfcell", sim(15,-35,60,120,600,20,lambda t: 60<t<=2820,dur=3600))
print("wagon", sim(15,-10,35,60,300,5,on))
print("gleba", sim(25,0,25,60,300,3,lambda t: False))
print("aq chamber", sim(-40,0,25,60,300,3,lambda t: False))
print("aq vault", sim(-40,-35,60,120,600,20,lambda t: False))
