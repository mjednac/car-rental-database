
-- 1. CZYSZCZENIE POPRZEDNIEJ BAZY 

DROP VIEW IF EXISTS wypozyczenia_aktualne;
DROP VIEW IF EXISTS ranking_zarobkow;
DROP VIEW IF EXISTS szczegoly_wypozyczen;

DROP TABLE IF EXISTS Wypozyczenia CASCADE;
DROP TABLE IF EXISTS Auta CASCADE;
DROP TABLE IF EXISTS Klienci CASCADE;

-- 2. TWORZENIE TABEL

CREATE TABLE Klienci (
    id_klienta SERIAL PRIMARY KEY,
    imie VARCHAR(50) NOT NULL,
    nazwisko VARCHAR(50) NOT NULL,
    pesel VARCHAR(11) UNIQUE NOT NULL CHECK (pesel ~ '^[0-9]{11}$')
);

CREATE TABLE Auta (
    id_auta SERIAL PRIMARY KEY,
    marka VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    rocznik INT NOT NULL CHECK (rocznik BETWEEN 2000 AND EXTRACT(YEAR FROM CURRENT_DATE)::INT),
    rodzaj_nadwozia VARCHAR(20) NOT NULL CHECK (rodzaj_nadwozia IN ('hatchback', 'combi', 'cabriolet', 'sedan', 'SUV')),
    liczba_miejsc INT NOT NULL CHECK (liczba_miejsc BETWEEN 2 AND 9),
    skrzynia_biegow VARCHAR(20) NOT NULL CHECK (skrzynia_biegow IN ('manualna', 'automatyczna')),
    cena_za_dzien DECIMAL(10, 2) NOT NULL CHECK (cena_za_dzien > 0),
    status VARCHAR(20) DEFAULT 'Dostępne' CHECK (status IN ('Dostępne', 'Wypożyczone', 'W naprawie'))
);

CREATE TABLE Wypozyczenia (
    id_wypozyczenia SERIAL PRIMARY KEY,
    id_klienta INT NOT NULL REFERENCES Klienci(id_klienta) ON DELETE CASCADE,
    id_auta INT NOT NULL REFERENCES Auta(id_auta) ON DELETE CASCADE,
    data_od DATE NOT NULL,
    data_do DATE NOT NULL,
    koszt_calkowity DECIMAL(10, 2),
    CONSTRAINT chk_daty CHECK (data_do >= data_od)
);

-- 3. FUNKCJE I TRIGGERY

-- Trigger 1: Zmiana statusu auta po wypożyczeniu
CREATE OR REPLACE FUNCTION zmien_status_auta() RETURNS TRIGGER AS $$
BEGIN
    UPDATE Auta SET status = 'Wypożyczone' WHERE id_auta = NEW.id_auta;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_zaktualizuj_status_auta
AFTER INSERT ON Wypozyczenia
FOR EACH ROW EXECUTE FUNCTION zmien_status_auta();

-- Trigger 2: Automatyczne obliczanie kosztu całkowitego
CREATE OR REPLACE FUNCTION oblicz_koszt_wypozyczenia() RETURNS TRIGGER AS $$
DECLARE
    v_cena_za_dzien DECIMAL;
    v_liczba_dni INT;
BEGIN
    SELECT cena_za_dzien INTO v_cena_za_dzien FROM Auta WHERE id_auta = NEW.id_auta;
    v_liczba_dni := NEW.data_do - NEW.data_od;
    
    IF v_liczba_dni = 0 THEN
        v_liczba_dni := 1;
    END IF;
    
    NEW.koszt_calkowity := v_liczba_dni * v_cena_za_dzien;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_oblicz_koszt
BEFORE INSERT ON Wypozyczenia
FOR EACH ROW EXECUTE FUNCTION oblicz_koszt_wypozyczenia();

-- Funkcja 1: Szybkie wypożyczenie (Klient z ulicy chce wypożyczc auto, wpisujemy go do klientów i tworzymy wypożyczenie jednocześnie)
CREATE OR REPLACE FUNCTION szybkie_wyp(
    p_imie VARCHAR, p_nazwisko VARCHAR, p_pesel VARCHAR, p_id_auta INT, p_od DATE, p_do DATE
) RETURNS VOID AS $$
DECLARE
    v_status VARCHAR;
    v_nowe_id INT;
BEGIN
    SELECT status INTO v_status FROM Auta WHERE id_auta = p_id_auta;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Auto o ID % nie istnieje', p_id_auta;
    END IF;

    IF v_status <> 'Dostępne' THEN
        RAISE EXCEPTION 'Auto o ID % nie jest dostępne. Aktualny status: %', p_id_auta, v_status;
    END IF;

    INSERT INTO Klienci (imie, nazwisko, pesel)
    VALUES (p_imie, p_nazwisko, p_pesel)
    RETURNING id_klienta INTO v_nowe_id;

    INSERT INTO Wypozyczenia (id_klienta, id_auta, data_od, data_do)
    VALUES (v_nowe_id, p_id_auta, p_od, p_do);
END;
$$ LANGUAGE plpgsql;

-- Funkcja 2: Zwrot auta z kwotą do zapłaty
CREATE OR REPLACE FUNCTION zwrot(p_id_wypozyczenia INT)
RETURNS DECIMAL AS $$
DECLARE
    v_id_auta INT;
    v_kwota DECIMAL(10, 2);
BEGIN
    SELECT id_auta, koszt_calkowity
    INTO v_id_auta, v_kwota
    FROM Wypozyczenia
    WHERE id_wypozyczenia = p_id_wypozyczenia;

    IF v_id_auta IS NULL THEN
        RAISE EXCEPTION 'Wypożyczenie o ID % nie istnieje', p_id_wypozyczenia;
    END IF;

    UPDATE Auta
    SET status = 'Dostępne'
    WHERE id_auta = v_id_auta;

    RETURN v_kwota;
END;
$$ LANGUAGE plpgsql;

-- 4. WIDOKI I INDEKSY

CREATE VIEW szczegoly_wypozyczen AS
SELECT 
    w.id_wypozyczenia,
    k.imie,
    k.nazwisko,
    a.marka,
    a.model,
    a.rocznik,
    a.rodzaj_nadwozia,
    a.liczba_miejsc,
    a.skrzynia_biegow,
    w.data_od,
    w.data_do,
    w.koszt_calkowity
FROM Wypozyczenia w
JOIN Klienci k ON w.id_klienta = k.id_klienta
JOIN Auta a ON w.id_auta = a.id_auta;

CREATE VIEW ranking_zarobkow AS
SELECT 
    a.marka,
    a.model,
    a.rocznik,
    a.rodzaj_nadwozia,
    COUNT(w.id_wypozyczenia) AS liczba_wypozyczen,
    COALESCE(SUM(w.koszt_calkowity), 0) AS suma_zarobkow
FROM Auta a
LEFT JOIN Wypozyczenia w ON a.id_auta = w.id_auta
GROUP BY a.id_auta, a.marka, a.model, a.rocznik, a.rodzaj_nadwozia
ORDER BY suma_zarobkow DESC;

CREATE VIEW wypozyczenia_aktualne AS
SELECT 
    w.id_wypozyczenia,
    k.imie,
    k.nazwisko,
    a.marka,
    a.model,
    a.rocznik,
    a.rodzaj_nadwozia,
    a.skrzynia_biegow,
    w.data_do AS termin_oddania
FROM Wypozyczenia w
JOIN Klienci k ON w.id_klienta = k.id_klienta
JOIN Auta a ON w.id_auta = a.id_auta
WHERE a.status = 'Wypożyczone';

CREATE INDEX idx_auta_status ON Auta(status);
CREATE INDEX idx_auta_nadwozie ON Auta(rodzaj_nadwozia);
CREATE INDEX idx_wypozyczenia_daty ON Wypozyczenia(data_od, data_do);


-- 5. ROLE

DROP ROLE IF EXISTS pracownik;
DROP ROLE IF EXISTS kierownik;

CREATE ROLE pracownik LOGIN;
CREATE ROLE kierownik LOGIN;

GRANT SELECT, INSERT, UPDATE ON Klienci, Auta, Wypozyczenia TO pracownik;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO pracownik;
REVOKE DELETE ON Klienci, Auta, Wypozyczenia FROM pracownik;

GRANT SELECT, INSERT, UPDATE, DELETE ON Klienci, Auta, Wypozyczenia TO kierownik;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO kierownik;
