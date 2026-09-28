# Dokumentacija - sistem za preporuke (Recommendation sistem)

Ovaj dokument objasnjava kako radi "Recommendation" sistem u aplikaciji
Project Work Manager. Tekst je pisan jednostavnim jezikom, kao objasnjenje
kolegi studentu, bez puno strucnih izraza.

## Sta je ovo uopste?

Ovo je alat koji pomaze kancelariji (adminu, pripremi rada i projekt
menadzeru) da **prije nego sto projekat pocne** procijene:

- koliko sati posla ce projekat vjerovatno trebati,
- koliko radnika je potrebno da se stigne do roka,
- koliko dana bi projekat trebao trajati,
- i kako se ti sati dijele po vrstama posla (npr. zavarivanje, farbanje,
  sklapanje...).

U stvarnom zivotu, kad radionica dobije novu narudzbu (npr. "napravi mi
5 tona metalne konstrukcije za 10 radnih dana"), sef ne zna tacno koliko
ce to trajati dok se ne zavrsi. Ovaj sistem to pokusava pogoditi na osnovu
**prijasnjih, vec zavrsenih projekata** iste vrste.

Vazno je reci: ovo nije "AI" u smislu neuronskih mreza ili masinskog ucenja
sa ogromnim modelima. To je **obicna, jednostavna statistika** - linearna
regresija - objasnjena dalje u tekstu.

## Gdje se ovo nalazi u aplikaciji

- Ekran se zove **"Recommendations"** (Project Resource Estimation), i
  nalazi se samo u desktop aplikaciji (`pwm_desktop`), ne u mobilnoj.
- Frontend fajl: `frontend/pwm_desktop/lib/screens/recommendations_screen.dart`
- Backend endpoint: `POST /Recommendation/Estimate`
- Backend logika: `backend/pwm/pwm.Services/Implementations/RecommendationService.cs`

## Ko smije koristiti ovaj ekran?

Samo tri role imaju pristup:

- **Admin**
- **Work preparation** (priprema rada)
- **Project manager** (projekt menadzer)

Finansije i proizvodni radnici (Production worker) nemaju pristup, jer
procjena posla nije njihov posao.

## Sta korisnik unosi (3 stvari)

Na ekranu korisnik popuni tri polja i klikne dugme **"Estimate"**:

1. **Vrsta projekta** (Project category) - npr. neka kategorija projekata
   koja vec postoji u sistemu.
2. **Ocekivana tezina** (Tonnes) - koliko tona ce novi projekat imati.
3. **Rok** (Working days) - za koliko radnih dana projekat treba biti gotov.

## Kako sistem racuna procjenu (korak po korak)

Ovo je "srce" cijelog sistema, opisano jednostavno:

### 1. korak - trazi slicne, zavrsene projekte

Sistem prvo pronadje sve projekte iz baze koji:
- pripadaju **istoj kategoriji** koju je korisnik izabrao, i
- imaju status **"Delivered"** (znaci - vec su zavrseni i isporuceni).

Samo zavrseni projekti se racunaju, jer samo za njih znamo koliko su
sati stvarno potrosili (za projekat koji je jos u toku, ne znamo
konacan broj sati).

### 2. korak - provjera da li ima dovoljno podataka

Ako ima **manje od 3** ovakva zavrsena projekta, sistem odustaje i
javi poruku tipa "nema dovoljno podataka" - ne izmisljanje procjenu
niotkuda. Ovo je bitno, jer procjena napravljena na 1 ili 2 projekta
ne bi znacila skoro nista.

### 3. korak - linearna regresija (linija koja najbolje prati tacke)

Za svaku vrstu posla (npr. "zavarivanje", "farbanje"...) koja se ikad
radila na projektima te kategorije, sistem napravi graf:

- na jednoj osi je **tezina projekta u tonama**,
- na drugoj osi je **broj sati** utrosenih na tu vrstu posla.

Svaki prijasnji projekat je jedna tacka na tom grafu. Sistem onda povuce
**pravu liniju koja najbolje prolazi kroz te tacke** (to se zove linearna
regresija, metoda najmanjih kvadrata - u kodu je to funkcija `FitLine`).

Kad se ta linija nacrta, moze se izracunati: "za X tona, linija kaze da
ce trebati Y sati te vrste posla". To se onda uradi za tonazu koju je
korisnik upisao, za svaku vrstu posla posebno.

Primjer (izmisljen, samo da se razumije ideja):
- Prijasnji projekti kategorije "Konstrukcije": 2t/16h zavarivanja,
  4t/30h zavarivanja, 6t/46h zavarivanja.
- Linija koja prati te tacke kaze otprilike: sati = 7.5 * tone + 1.
- Ako korisnik trazi procjenu za 5 tona, sistem kaze: 5 tona ce
  trebati oko 38.5h zavarivanja.

### 4. korak - koliko je procjena tacna?

Sistem racuna i jedan broj koji se zove **tacnost (accuracy), 0-100%**.
To pokazuje koliko dobro ta linija zapravo odgovara stvarnim, proslim
podacima (u statistici se ovo zove R-kvadrat / R²). Ako je tacnost
visoka (npr. 90%), znaci da je tezina projekta jako dobar pokazatelj
koliko ce sati trebati. Ako je niska (npr. 20%), znaci da tezina
projekta i broj sati nisu bas usko povezani, pa procjenu treba uzeti
sa rezervom.

Ovaj broj se racuna malo drugacije nego procjena po vrsti posla - ovdje
se posmatra **ukupan** broj sati (svih vrsta posla zajedno) naspram
tezine, da se dobije jedna opsta ocjena "koliko tezina uopste objasnjava
trajanje posla" za tu kategoriju projekata.

### 5. korak - sabiranje svega u konacan odgovor

- **Ukupni sati** (Total Hours) = zbir procijenjenih sati svih vrsta posla.
- **Udio po vrsti posla** (Share %) = koliki procenat od ukupnih sati
  otpada na svaku vrstu posla (npr. zavarivanje 40%, farbanje 15%...).
- **Broj radnika** (Estimated Workers) = ukupni sati podijeljeni sa
  (rok u danima * 8 sati po radniku dnevno), zaokruzeno na gore. Ovo
  odgovara na pitanje: "koliko radnika mi treba da stignem do roka?"
- **Trajanje** (Estimated Duration Days) = ukupni sati podijeljeni sa
  (tipicna velicina ekipe * 8 sati dnevno). Tipicna velicina ekipe se
  racuna kao prosjecan broj razlicitih radnika koji su radili na
  prijasnjim projektima te kategorije. Ovo odgovara na pitanje: "koliko
  bi ovo obicno trajalo sa uobicajenim brojem radnika?"

Vrste posla sa jako malim brojem procijenjenih sati (manje od 0.05h) se
ne prikazuju, jer prakticno ne postoje za tu kategoriju.

## Sta korisnik vidi na ekranu

Kad se procjena zavrsi, prikazu se:

- 4 kartice na vrhu: ukupni sati, broj radnika, trajanje u danima, i broj
  proslih projekata na kojima se procjena zasniva (plus % tacnosti).
- Recenica objasnjenja ("Explanation") - ljudskim jezikom kaze na osnovu
  koliko projekata je procjena napravljena i koliko je tacna. Ovo je
  namjerno - procjena se nikad ne prikazuje kao "goli broj" bez
  objasnjenja odakle dolazi.
- Tabela po vrstama posla - naziv, traka koja vizuelno prikazuje udio,
  broj sati, i procenat udjela.

Ako nema dovoljno podataka (manje od 3 zavrsena projekta), umjesto tabele
prikaze se poruka koja to objasnjava.

## Bitne napomene

- **Nista se ne cuva u bazi.** Svaki put kad korisnik klikne "Estimate",
  sistem ponovo racuna sve od pocetka, na osnovu trenutnog stanja baze.
  To znaci da ce procjene s vremenom postajati sve bolje, kako radionica
  zavrsava vise projekata (vise podataka = bolja linija = tacnija procjena).
- Tezina projekta se u bazi cuva u kilogramima, a ovdje se racuna u
  tonama (dijeli se sa 1000).
- 8 sati po radniku dnevno je fiksna vrijednost koja se koristi i na
  drugim mjestima u aplikaciji (izvjestaji, radni sati), da bude
  konzistentno kroz cijelu aplikaciju.
- Minimalan broj proslih projekata potreban za procjenu je 3
  (`RecommendationService.MinSampleSize`).

## Za koga je ovo korisno (developerska napomena)

Ako neko u buducnosti zeli da poboljsa ovaj sistem, evo par ideja:
- Umjesto obicne linearne regresije, moglo bi se probati sa vise faktora
  odjednom (npr. tezina + broj razlicitih materijala), sto bi bio
  slozeniji statisticki model.
- Trenutno se sve racuna "uzivo" (in-memory) pri svakom pozivu - za
  jako veliku kolicinu podataka, ovo bi moglo trebati keširanje.
- Prag od 3 projekta (`MinSampleSize`) je proizvoljno odabran broj -
  moze se mijenjati zavisno od toga koliko se stroga zeli procjena.
