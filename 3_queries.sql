

-- Wyświetlenie szczegółów wszystkich wypożyczeń w historii
SELECT * FROM szczegoly_wypozyczen;

-- Wyświetlenie rankingu zarobków aut
SELECT * FROM ranking_zarobkow;

-- Wyświetlenie aktualnie trwających wypożyczeń
SELECT * FROM wypozyczenia_aktualne;

-- Wyszukanie dostępnych SUV-ów z automatyczną skrzynią biegów
SELECT marka, model, rocznik, liczba_miejsc, cena_za_dzien
FROM Auta
WHERE rodzaj_nadwozia = 'SUV'
  AND skrzynia_biegow = 'automatyczna'
  AND status = 'Dostępne'
ORDER BY cena_za_dzien;

-- Wyszukanie aut według liczby miejsc i rodzaju nadwozia
SELECT marka, model, rocznik, rodzaj_nadwozia, liczba_miejsc
FROM Auta
WHERE liczba_miejsc >= 5
  AND rodzaj_nadwozia IN ('combi', 'SUV')
ORDER BY rocznik DESC;

-- Liczba aut według rodzaju nadwozia
SELECT rodzaj_nadwozia, COUNT(*) AS liczba_aut
FROM Auta
GROUP BY rodzaj_nadwozia
ORDER BY liczba_aut DESC;

-- Liczba aut według skrzyni biegów
SELECT skrzynia_biegow, COUNT(*) AS liczba_aut
FROM Auta
GROUP BY skrzynia_biegow;

-- Średnia cena wynajmu według rodzaju nadwozia
SELECT rodzaj_nadwozia, ROUND(AVG(cena_za_dzien), 2) AS srednia_cena_za_dzien
FROM Auta
GROUP BY rodzaj_nadwozia
ORDER BY srednia_cena_za_dzien DESC;

-- Zaawansowany ranking klientów według wydatków, z funkcją okna RANK
SELECT 
    k.imie, 
    k.nazwisko, 
    SUM(w.koszt_calkowity) AS suma_wydatkow,
    RANK() OVER(ORDER BY SUM(w.koszt_calkowity) DESC) AS miejsce_w_rankingu
FROM Klienci k
JOIN Wypozyczenia w ON k.id_klienta = w.id_klienta
GROUP BY k.id_klienta, k.imie, k.nazwisko;

-- 2. TEST FUNKCJI

--Próba wypożyczenia zajętego auta, czyli zabezpieczenie powinno zgłosić błąd.
SELECT szybkie_wyp('Bartosz', 'Zmarzlik', '95041212345', 22, '2026-07-01', '2026-07-05'); 

-- Obsługa zwrotu pojazdu.
-- Funkcja odblokuje auto i wyświetli kwotę do zapłaty.
SELECT zwrot(1);

-- Sprawdzenie, czy auto po zwrocie ma status Dostępne
SELECT id_auta, marka, model, status
FROM Auta
WHERE id_auta = 1;

-- 3. OBSŁUGA TRANSAKCJI

--Wycofanie błędu
BEGIN;
UPDATE Wypozyczenia SET data_do = '2026-12-31' WHERE id_wypozyczenia = 1;
UPDATE Wypozyczenia SET koszt_calkowity = 99999.00 WHERE id_wypozyczenia = 1;
ROLLBACK;

--Sukces transakcji
BEGIN;
UPDATE Wypozyczenia SET data_do = data_do + 2 WHERE id_wypozyczenia = 2;
UPDATE Wypozyczenia SET koszt_calkowity = koszt_calkowity + 480.00 WHERE id_wypozyczenia = 2;
COMMIT;
