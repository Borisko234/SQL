CREATE TABLE "TypPracovniSmlouvy" (
  "typ_id" integer PRIMARY KEY NOT NULL,
  "nazev" varchar NOT NULL,
  "popis" varchar
);

CREATE TABLE "Zamestnanec" (
  "zamestnanec_id" integer PRIMARY KEY NOT NULL,
  "jmeno" varchar NOT NULL,
  "prijmeni" varchar NOT NULL,
  "datum_nastupu" date,
  "bankovni_udaje" varchar NOT NULL,
  "adresa" varchar,
  "supervisor_id" integer,
  "typ_id" integer NOT NULL
);

CREATE TABLE "Kuchar" (
  "kuchar_id" integer PRIMARY KEY NOT NULL,
  "specializace" varchar NOT NULL
);

CREATE TABLE "Cisnik" (
  "cisnik_id" integer PRIMARY KEY NOT NULL,
  "zletilost" boolean NOT NULL
);

CREATE TABLE "Stul" (
  "stul_id" integer PRIMARY KEY NOT NULL,
  "cislo_stolu" integer NOT NULL,
  "lokalita" varchar NOT NULL,
  "kapacita" integer,
  "dostupnost" varchar
);

CREATE TABLE "Rezervace" (
  "rezervace_id" integer PRIMARY KEY NOT NULL,
  "datum_cas" datetime NOT NULL,
  "pocet_osob" integer NOT NULL,
  "stav" varchar NOT NULL,
  "stul_id" integer NOT NULL
);

CREATE TABLE "Objednavka" (
  "objednavka_id" integer PRIMARY KEY NOT NULL,
  "datum_cas" datetime NOT NULL,
  "cislo" integer NOT NULL,
  "zpusob_platby" varchar NOT NULL,
  "stav" varchar NOT NULL,
  "poznamka" varchar,
  "cisnik_id" integer NOT NULL,
  "stul_id" integer NOT NULL
);

CREATE TABLE "PolozkaMenu" (
  "polozka_id" integer PRIMARY KEY NOT NULL,
  "nazev" varchar NOT NULL,
  "cena" decimal(10,2) NOT NULL,
  "alergen" varchar,
  "dostupnost" varchar
);

CREATE TABLE "PolozkaObjednavky" (
  "polozka_objednavky_id" integer PRIMARY KEY NOT NULL,
  "pocet_kusu" integer NOT NULL,
  "stav" varchar NOT NULL,
  "poznamka" varchar,
  "objednavka_id" integer NOT NULL,
  "polozka_id" integer NOT NULL
);

ALTER TABLE "Zamestnanec" ADD FOREIGN KEY ("typ_id") REFERENCES "TypPracovniSmlouvy" ("typ_id");

ALTER TABLE "Zamestnanec" ADD FOREIGN KEY ("supervisor_id") REFERENCES "Zamestnanec" ("zamestnanec_id");

ALTER TABLE "Kuchar" ADD FOREIGN KEY ("kuchar_id") REFERENCES "Zamestnanec" ("zamestnanec_id");

ALTER TABLE "Cisnik" ADD FOREIGN KEY ("cisnik_id") REFERENCES "Zamestnanec" ("zamestnanec_id");

ALTER TABLE "Rezervace" ADD FOREIGN KEY ("stul_id") REFERENCES "Stul" ("stul_id");

ALTER TABLE "Objednavka" ADD FOREIGN KEY ("cisnik_id") REFERENCES "Cisnik" ("cisnik_id");

ALTER TABLE "Objednavka" ADD FOREIGN KEY ("stul_id") REFERENCES "Stul" ("stul_id");

ALTER TABLE "PolozkaObjednavky" ADD FOREIGN KEY ("objednavka_id") REFERENCES "Objednavka" ("objednavka_id");

ALTER TABLE "PolozkaObjednavky" ADD FOREIGN KEY ("polozka_id") REFERENCES "PolozkaMenu" ("polozka_id");



-- BONUS

-- Transactions
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
DO $$
DECLARE
 v_dostupnost text;
 v_rezervace_cas timestamp;
BEGIN
 v_rezervace_cas := CURRENT_TIMESTAMP + INTERVAL '1 hour';
 BEGIN
 -- 1) Check table availability
 SELECT "dostupnost" INTO v_dostupnost
 FROM "Stul"
 WHERE "cislo_stolu" = 5
 FOR UPDATE;
 IF v_dostupnost NOT IN ('volný', 'neaktivní') THEN
 RAISE NOTICE 'Stůl č.5 není dostupný. Aktuální stav: %', v_dostupnost;
 RETURN;
 END IF;
 -- 2) Creating new reservation with time +1
 INSERT INTO "Rezervace" ("datum_cas", "pocet_osob", "stav", "cislo_stolu")
 VALUES (v_rezervace_cas, 4, 'potvrzená', 5);
 -- 3) Update table availability
 UPDATE "Stul"
 SET "dostupnost" = 'rezervovaný'
 WHERE "cislo_stolu" = 5;
 RAISE NOTICE 'Rezervace stolu č.5 na % byla úspěšně vytvořena', v_rezervace_cas;
 EXCEPTION
 WHEN serialization_failure THEN
 RAISE NOTICE 'Rezervace se nepovedla kvůli konfliktu, zkuste to prosím znovu';
 WHEN OTHERS THEN
 RAISE NOTICE 'Došlo k neočekávané chybě: %', SQLERRM;
 END;
END $$; 

-- View
CREATE VIEW dnesni_rezervace AS
SELECT
 r.rezervace_id,
 r.datum_cas,
 r.pocet_osob,
 r.cislo_stolu
FROM
 "Rezervace" r
JOIN
 "Objednavka" o ON r.cislo_stolu = o.cislo_stolu
WHERE
 DATE(r.datum_cas) = CURRENT_DATE
ORDER BY
 r.datum_cas; 

-- Trigger
BEGIN
 IF NEW.stav = 'zrušená' THEN
 UPDATE "Stul"
 SET dostupnost = 'volný'
 WHERE cislo_stolu = NEW.cislo_stolu;
 END IF;
 RETURN NEW;
END;

-- Script for creating trigger
CREATE OR REPLACE TRIGGER trg_cancel_rezervace
 AFTER UPDATE
 ON public."Rezervace"
 FOR EACH ROW
 EXECUTE FUNCTION public.trg_cancel_rezervace_fn(); 

-- Index
CREATE INDEX idx_stul_dostupnost
 ON public."Stul" USING btree
 (dostupnost ASC NULLS LAST)
 WITH (deduplicate_items=True)
;
CREATE INDEX idx_stul_dostupnost
ON "Stul" ("dostupnost"); 


