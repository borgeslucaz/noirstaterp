# Grot FastMechanic

**Grot FastMechanic** to zaawansowany, darmowy i w pełni konfigurowalny skrypt na interfejs mechanika samochodowego (VMenu-style NUI) dla serwerów FiveM. Pozwala on na kompleksowy tuning wizualny i mechaniczny, edycję handlingu w czasie rzeczywistym oraz dostosowanie najdrobniejszych detali pojazdu z poziomu nowoczesnego interfejsu stworzonego w HTML, grafitowym CSS i JavaScript. Skrypt obsługuje również modyfikacje typu "Stance" (pochylenie i dystanse kół).

---

## 🚀 Główne Funkcje (Cechy Skryptu)

- **Nowoczesny Interfejs (NUI):** Przejrzysty, ciemny design (Glassmorphism), ukryty suwak przewijania (scrollbar) oraz wbudowane ikony SVG (FontAwesome 6). Skrypt dzieli tuning na zakładki: *Mechaniczny*, *Wizualny* oraz *Handling*.
- **Tuning Mechaniczny i Wizualny:** Podstawowe osiągi (silnik, turbo, hamulce, pancerz) oraz wszystkie możliwe zmiany wizualne dostępne w GTA V (spoilery, zderzaki, osłony, maski, wyposażenie wnętrza, klatki bezpieczeństwa, audio, dodatki).
- **Zaawansowane Warianty Kolorów:** Zmiana lakieru (Główny, Dodatkowy, Perłowy), koloru felg, koloru deski rozdzielczej (Dashboard) i wnętrza (Interior).
- **Rozbudowany Moduł Oświetlenia i Kół:**
  - **Neony i Dym spod opon:** Dokładny wybór koloru z użyciem innowacyjnych suwaków RGB (od 0 do 255). Neony można włączać na poszczególne strefy pojazdu (przód, tył, lewo, prawo).
  - **Xenony:** Aktywacja oraz wybór dokładnego koloru światła Xenon (14 dostępnych wersji kolorów min. UV, różowe).
  - **Szyby:** Przyciemnianie szyb pojazdu.
  - **Felgi:** Możliwość wyboru typu kół (Sport, Offroad itp.) i dynamiczny suwak do wybierania konkretnego modelu felgi (wzoru) danej kategorii.
- **Handling w Czasie Rzeczywistym:**
  - Przyspieszenie, V-Max, Siła hamowania, Przyczepność, Wysokość zawieszenia, Docisk (Downforce).
  - **System STANCE:** Edycja dystansów kół (Track Width) oraz ich pochylenia negatyw/pozytyw (Camber).
  - System zapamiętywania handlingu dla konkretnego wozu po wyłączeniu UI – dane tuningowe persistują dopóki jesteś w tym samym pojeździe.
- **Dodatkowe Zdalne Akcje:** Otwieranie/zamykanie poszczególnych drzwi, czyszczenie i natychmiastowa naprawa oraz system resetowania auta do stanu seryjnego z potwierdzeniem (modalem).
- **System Lokalizacji (Locales):** Pełen system tłumaczeń dynamicznych (i18n). Możliwość przełączania języków UI (`'en'` lub `'pl'`) w pliku `config.lua` bez modyfikowania HTML/JS. Pliki tłumaczeń generowane i ładowane przez Lua w locie do NUI.
- **Eksploracja Pojazdu (Kamera):** Możliwość trzymania Lewego lub Prawego przycisku myszy będąc w wolnym polu ekranu, celem zablokowania responsywności UI i swobodnego obracania kamerą wokół pojazdu w celu oceny efektów tuningu.

---

## 📂 Struktura Plików

- `fxmanifest.lua` - Plik z logiką inicjacyjną zasobu (obsługuje nowoczesny typ `cerulean` i sekcję `shared_scripts`).
- `config.lua` - Główne opcje (skróty klawiszowe, dozwolone kategorie tuningu, lista blipów mechanika powiązana z koordynatami w świecie, baza dostępnych lakierów).
- `client.lua` - Główny silnik logiczny odpowiadający za fetching i nakładanie modyfikacji (FiveM Natives), zarządzający zdarzeniami aparatu pojazdu (Pochylenie/Szerokość), przechwytujący wejście NUI callback poprzez `/tunetest` i blipy mapy. Posiada system cache dla powracającego Handlingu.
- `server.lua` - System odbierania i autoryzacji eventów lub modyfikacji w środowisku Multiplayer na serwerze (synchronizacja dla innych graczy np. logi mechanika).
- `locales/`
  - `init.lua` - Skrypt definiujący funkcję tłumaczeń i słownik globalny.
  - `pl.lua`, `en.lua` - Słowniki (key-value) ze stringami w odpowiednich językach.
- `html/`
  - `index.html` - Plik szkieletowy UI NUI ładowany przez grę. Zawiera siatkę aplikacji i znaczniki `data-i18n`.
  - `style.css` - Arkusz stylów obsługujący ciemny layout graficzny, podświetlenia typu hover, modale i siatki sliderów obsługujących Handling i RGB.
  - `script.js` - Silnik frontendowy nasłuchujący NUI z klienta i dynamicznie manipulujący elementami DOM (generowanie sliderów, fetchowanie parametrów kolorów i felg, odsyłanie callbacków "applyMod" oraz "applyHandling" do `client.lua`).

## 🛠️ Jak dodać to do AI?
Skopiuj cały powyższy plik jako swój kontekst bazowy, aby każdy twój kolejny wielki model graficzny albo programistyczny (LLM / Claude / ChatGPT) od razu wiedział z jakimi plikami, klasami CSS oraz funkcjami w Lua ma do czynienia w obrębie Grot FastMechanic.
