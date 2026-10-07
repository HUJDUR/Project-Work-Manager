# Sistem preporuke - procjena resursa projekta

Prije početka novog projekta sistem procjenjuje koliko će sati posla trebati, po
vrstama posla, koliko radnika je potrebno i koliko će projekat trajati. Procjena
se pravi na osnovu ranije isporučenih projekata iste kategorije.

## Gdje i ko

- Desktop aplikacija, ekran **Recommendations**.
- Pristup: Admin, Work preparation i Project manager.
- Endpoint: `POST /Recommendation/Estimate`, logika u
  `backend/pwm/pwm.Services/Implementations/RecommendationService.cs`.

## Ulaz

- kategorija projekta
- očekivana težina u tonama
- rok u radnim danima

## Kako se računa

1. Uzimaju se svi projekti iste kategorije sa statusom **Delivered**. Samo za
   njih je poznat konačan broj sati.
2. Ako ih je manje od 3, procjena se ne prikazuje, nego poruka da nema dovoljno
   podataka.
3. Za svaku vrstu posla (zavarivanje, brušenje...) sistem iz tih projekata
   pravi **linearnu regresiju**: liniju koja povezuje težinu projekta i broj
   sati te vrste posla. Na toj liniji se očita broj sati za unesenu težinu.
4. Rezultat:
   - **ukupni sati** - zbir sati svih vrsta posla, uz udio svake vrste u %
   - **broj radnika** - ukupni sati / (rok × 8 h), zaokruženo naviše
   - **trajanje** - ukupni sati / (uobičajen broj radnika na takvim projektima × 8 h)

Svi podaci dolaze iz evidencije rada u aplikaciji: sati iz clock-in/clock-out i
ručnih unosa, težina i status iz projekata. Ništa se ne čuva - procjena se
računa ponovo pri svakom pozivu, pa je sve tačnija što je više isporučenih
projekata.

## Objašnjenje procjene

Uz svaku procjenu prikazuje se:

- **na osnovu koliko projekata** je napravljena
- **tačnost** (R², 0-100 %) - koliko dobro težina objašnjava ukupan broj sati
  kod ranijih projekata te kategorije. Niska tačnost znači da procjenu treba
  uzeti s rezervom.
- rečenica koja to oboje kaže riječima

Procjena je pomoć pri planiranju, a ne konačna odluka.
