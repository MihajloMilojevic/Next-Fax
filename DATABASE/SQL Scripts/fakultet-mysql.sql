CREATE DATABASE IF NOT EXISTS fakultet CHARACTER SET UTF8 COLLATE utf8_bin;
USE fakultet;

-- TABELE --
CREATE TABLE IF NOT EXISTS grupe(
	id_grupe INT AUTO_INCREMENT PRIMARY KEY,
	naziv VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS smerovi(
	id_smera INT AUTO_INCREMENT PRIMARY KEY,
	naziv VARCHAR(100) NOT NULL,
	id_grupe INT NOT NULL REFERENCES grupe(id_grupe)
);

CREATE TABLE IF NOT EXISTS gradovi(
	id_grada INT PRIMARY KEY,
	naziv VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS profesori(
	id_profesora INT AUTO_INCREMENT PRIMARY KEY,
	jmbg VARCHAR(13) UNIQUE NOT NULL CHECK (LENGTH(jmbg) = 13),
	ime VARCHAR(50) NOT NULL,
	prezime VARCHAR(50) NOT NULL,
	mejl VARCHAR(70) NOT NULL UNIQUE,
	adresa VARCHAR(100) NOT NULL,
	telefon VARCHAR(20) NOT NULL,
	plata INT NOT NULL
);

CREATE TABLE IF NOT EXISTS studenti(
	broj_indeksa VARCHAR(20) PRIMARY KEY,
	jmbg VARCHAR(13) UNIQUE NOT NULL CHECK (LENGTH(jmbg) = 13),
	ime VARCHAR(50) NOT NULL,
	prezime VARCHAR(50) NOT NULL,
	mejl VARCHAR(70) NOT NULL UNIQUE,
	id_grada INT NOT NULL REFERENCES gradovi(id_grada),
	id_smera INT NOT NULL REFERENCES smerovi(id_smera)
);

CREATE TABLE IF NOT EXISTS predmeti(
	id_predmeta INT AUTO_INCREMENT PRIMARY KEY,
	naziv VARCHAR(50) NOT NULL,
	id_smera INT NOT NULL REFERENCES smerovi(id_smera),
	id_profesora INT NOT NULL REFERENCES profesori(id_profesora),
	nedeljni_fond INT NOT NULL
);

CREATE TABLE IF NOT EXISTS zavisnosti(
	id_predmeta_od INT NOT NULL REFERENCES predmeti(id_predmeta),
	id_predmeta_ko INT NOT NULL REFERENCES predmeti(id_predmeta),
	PRIMARY KEY(id_predmeta_od, id_predmeta_ko)
);

CREATE TABLE IF NOT EXISTS ispiti(
	id_ispita INT AUTO_INCREMENT PRIMARY KEY,
	id_predmeta INT NOT NULL REFERENCES predmeti(id_predmeta),
	datum DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS slusanja(
	id_predmeta INT NOT NULL REFERENCES predmeti(id_predmeta),
	broj_indeksa VARCHAR(20) NOT NULL REFERENCES studenti(broj_indeksa),
	zavrseno BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (id_predmeta, broj_indeksa)
);

CREATE TABLE IF NOT EXISTS polaganja(
	id_polaganja INT AUTO_INCREMENT PRIMARY KEY,
	broj_indeksa VARCHAR(20) NOT NULL REFERENCES studenti(broj_indeksa),
	id_ispita INT NOT NULL REFERENCES ispiti(id_ispita),
	ocena INT CHECK (ocena BETWEEN 5 AND 10)
);

CREATE TABLE IF NOT EXISTS admini(
	id_admina INT AUTO_INCREMENT PRIMARY KEY,
	jmbg VARCHAR(13) UNIQUE NOT NULL CHECK (LENGTH(jmbg) = 13),
	ime VARCHAR(50) NOT NULL,
	prezime VARCHAR(50) NOT NULL,
	mejl VARCHAR(70) NOT NULL UNIQUE,
	adresa VARCHAR(100) NOT NULL,
	telefon VARCHAR(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS korisnici(
	mejl VARCHAR(70) NOT NULL PRIMARY KEY,
	lozinka VARCHAR(100) NOT NULL,
	uloga VARCHAR(50) NOT NULL CHECK (uloga IN('admin', 'profesor', 'student')),
	id_profesora INT REFERENCES	profesori(id_profesora0),
	broj_indeksa VARCHAR(20) REFERENCES studenti(broj_indeksa),
	id_admina INT REFERENCES admini(id_admina),
	CHECK ((id_profesora IS NULL AND broj_indeksa IS NULL AND id_admina IS NOT NULL AND uloga = 'admin') OR
		  (id_profesora IS NULL AND broj_indeksa IS NOT NULL AND id_admina IS NULL AND uloga = 'student') OR
		  (id_profesora IS NOT NULL AND broj_indeksa IS NULL AND id_admina IS NULL AND uloga = 'profesor'))
);

-- FUNKCIJE --

DELIMITER //

CREATE FUNCTION IF NOT EXISTS mozeDaUpise(broj_indeksa_in VARCHAR(20), id_predmeta_in INT)
RETURNS INT
BEGIN
	DECLARE brojZavisnihPredmeta INT;
    DECLARE brojOdsusanihPredmeta INT;
    DECLARE student_id_smera INT;
    DECLARE predmet_id_smera INT;
   	
    SET student_id_smera = (SELECT id_smera FROM studenti WHERE broj_indeksa = broj_indeksa_in);
    SET predmet_id_smera = (SELECT id_smera FROM predmeti WHERE id_predmeta = id_predmeta_in);
    
    SET brojZavisnihPredmeta = (SELECT COUNT(*) FROM zavisnosti WHERE id_predmeta_ko = id_predmeta_in);
    SET brojOdsusanihPredmeta = (
        SELECT COUNT(*) 
        FROM slusanja 
        WHERE broj_indeksa = broj_indeksa_in AND 
        	id_predmeta IN( SELECT id_predmeta_od FROM zavisnosti WHERE id_predmeta_ko = id_predmeta_in) AND
        	zavrseno IS TRUE
        );
   RETURN brojZavisnihPredmeta = brojOdsusanihPredmeta AND student_id_smera = predmet_id_smera;
END; //

CREATE FUNCTION IF NOT EXISTS prestupnaGodina(godina INT)
RETURNS INT
BEGIN
	IF((godina % 4 = 0 AND godina % 100 <> 0) OR godina % 400 = 0) THEN
    	RETURN 1;
    END IF;
    RETURN 0;
END; //

CREATE FUNCTION IF NOT EXISTS brojDanaUMesecu(mesec INT, godina INT)
RETURNS INT
BEGIN
	CASE
        WHEN mesec IN(1, 3, 5, 7, 8, 10, 12) THEN RETURN 31;
        WHEN mesec IN(4, 6, 9, 11) THEN RETURN 30;
        WHEN mesec = 2 THEN RETURN (28 + prestupnaGodina(godina));
        ELSE SIGNAL SQLSTATE 'HY000' SET MESSAGE_TEXT = 'INVALID MONTH NUMBER', MYSQL_ERRNO = 1369;
    END CASE;
END; //

CREATE FUNCTION IF NOT EXISTS godinaIzJMBG(jmbg VARCHAR(13))
RETURNS INT
BEGIN
	DECLARE godina INT;
    DECLARE prvaCifra INT;
    
    SET godina = CAST(SUBSTR(jmbg, 5, 3) AS UNSIGNED);
    
    IF SUBSTR(jmbg, 5, 1) = '9' THEN 
    	SET prvaCifra = 1;
    ELSE 
    	SET prvaCifra = 2;
    END IF;
    
    RETURN (prvaCifra * 1000 + godina);
    
END; //

CREATE FUNCTION IF NOT EXISTS mesecIzJMBG(jmbg VARCHAR(13))
RETURNS INT
BEGIN
    RETURN CAST(SUBSTR(jmbg, 3, 2) AS UNSIGNED);
    
END; //

CREATE FUNCTION IF NOT EXISTS danIzJMBG(jmbg VARCHAR(13))
RETURNS INT
BEGIN
    RETURN CAST(SUBSTR(jmbg, 1, 2) AS UNSIGNED);
END; //

CREATE FUNCTION IF NOT EXISTS proveraJMBG(jmbg VARCHAR(13))
RETURNS INT
BEGIN
	DECLARE dan INT;
	DECLARE mesec INT;
	DECLARE godina INT;
    
    SET dan = danIzJMBG(jmbg);
    SET mesec = mesecIzJMBG(jmbg);
    SET godina = godinaIzJMBG(jmbg);
    
	IF LENGTH(jmbg) <> 13 OR mesec NOT BETWEEN 1 AND 12 OR dan > brojDanaUMesecu(mesec, godina)
    	THEN RETURN 0;
    END IF;
    RETURN 1;
END; //

CREATE FUNCTION IF NOT EXISTS proveraPolaganja(broj_indeksa_in VARCHAR(20), id_ispita_in INT)
RETURNS INT
BEGIN
	DECLARE id_predmeta_in INT;
	SET id_predmeta_in = (SELECT id_predmeta FROM ispiti WHERE id_ispita = id_ispita_in);
	RETURN ((SELECT COUNT(*) FROM slusanja WHERE broj_indeksa = broj_indeksa_in AND id_predmeta = id_predmeta_in) = 1);
END; //

-- OKIDAČI --

CREATE TRIGGER IF NOT EXISTS slusanja_before_insert
BEFORE INSERT
   ON slusanja FOR EACH ROW
BEGIN
	IF(mozeDaUpise(NEW.broj_indeksa, NEW.id_predmeta) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR slusanja FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS slusanja_before_update
BEFORE UPDATE
   ON slusanja FOR EACH ROW
BEGIN
	IF(mozeDaUpise(NEW.broj_indeksa, NEW.id_predmeta) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR slusanja FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS profesori_before_insert
BEFORE INSERT
ON profesori FOR EACH ROW
BEGIN
	IF(proveraJMBG(NEW.jmbg) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR profesori FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS profesori_before_update
BEFORE UPDATE
ON profesori FOR EACH ROW
BEGIN
	IF(proveraJMBG(NEW.jmbg) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR profesori FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS studenti_before_insert
BEFORE INSERT
ON studenti FOR EACH ROW
BEGIN
	IF(proveraJMBG(NEW.jmbg) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR studenti FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS studenti_before_update
BEFORE UPDATE
ON studenti FOR EACH ROW
BEGIN
	IF(proveraJMBG(NEW.jmbg) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR studenti FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS admini_before_insert
BEFORE INSERT
ON admini FOR EACH ROW
BEGIN
	IF(proveraJMBG(NEW.jmbg) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR admini FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS admini_before_update
BEFORE UPDATE
ON admini FOR EACH ROW
BEGIN
	IF(proveraJMBG(NEW.jmbg) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR admini FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS polaganja_before_insert
BEFORE INSERT
   ON polaganja FOR EACH ROW
BEGIN
	IF(proveraPolaganja(NEW.broj_indeksa, NEW.id_ispita) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR polagnja FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS polaganja_before_update
BEFORE UPDATE
   ON polaganja FOR EACH ROW
BEGIN
	IF(proveraPolaganja(NEW.broj_indeksa, NEW.id_ispita) = 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'CHECK CONSTRAINT FOR polaganja FAILED', MYSQL_ERRNO = 1369;
    END IF;
END; //

CREATE TRIGGER IF NOT EXISTS predmeti_before_delete
BEFORE DELETE
ON predmeti FOR EACH ROW
BEGIN
	IF((SELECT COUNT(*) FROM zavisnosti WHERE id_predmeta_od = OLD.id_predmeta) <> 0) THEN
    	SIGNAL SQLSTATE 'HY000'
                 SET MESSAGE_TEXT = 'Drugi predmet zavisi od ovog predmeta', MYSQL_ERRNO = 1369;
    END IF;
    DELETE FROM zavisnosti WHERE id_predmeta_ko = OLD.id_predmeta;
END; //

CREATE TRIGGER IF NOT EXISTS studenti_korisnik
AFTER INSERT
   ON studenti FOR EACH ROW
BEGIN
	INSERT INTO korisnici(
		mejl,
		lozinka, 
		uloga,	
		id_profesora, 
		broj_indeksa, 
		id_admina
	)
	VALUES (
		NEW.mejl, 
		'$2a$10$1nCEZiJ5Wr1jlHaqgke2gu0QSr7pcp6BU6rMqJFilZc2e7YCcG5z6',
		'student',
		NULL,
		NEW.broj_indeksa,
		NULL
	);
END; //

CREATE TRIGGER IF NOT EXISTS profesori_korisnik
AFTER INSERT
   ON profesori FOR EACH ROW
BEGIN
	INSERT INTO korisnici(
		mejl,
		lozinka, 
		uloga,	
		id_profesora, 
		broj_indeksa, 
		id_admina
	)
	VALUES (
		NEW.mejl, 
		'$2a$10$hb5tiBlLtOL7tI/93FBdau2JlHGp0aRfsSxM2PCyppvTWDNTUWldm',
		'profesor',
		NEW.id_profesora,
		NULL,
		NULL
	);
END; //

CREATE TRIGGER IF NOT EXISTS admini_korisnik
AFTER INSERT
   ON admini FOR EACH ROW
BEGIN
	INSERT INTO korisnici(
		mejl,
		lozinka, 
		uloga,	
		id_profesora, 
		broj_indeksa, 
		id_admina
	)
	VALUES (
		NEW.mejl, 
		'$2a$10$71CUMGrO7JppfgHQ0xUHBeRMAEP2YygX8AeGsFeUvbj06rJrVnJhe',
		'admin',
		NULL,
		NULL,
		NEW.id_admina
	);
END; //

DELIMITER ;

-- PODACI --

-- GRADOVI --

INSERT INTO gradovi (id_grada, naziv)
VALUES
(24430, 'Ada'),
(12370, 'Aleksandrovac'),
(37230, 'Aleksandrovac'),
(18220, 'Aleksinac'),
(26310, 'Alibunar'),
(25260, 'Apatin'),
(34300, 'Aranđelovac'),
(31230, 'Arilje'),
(18330, 'Babušnica'),
(21420, 'Bač'),
(21400, 'Bačka Palanka'),
(24300, 'Bačka Topola'),
(21470, 'Bački Petrovac'),
(31250, 'Bajina Bašta'),
(11460, 'Barajevo'),
(34227, 'Batočina'),
(21220, 'Bečej'),
(15313, 'Bela Crkva'),
(26340, 'Bela Crkva'),
(18310, 'Bela Palanka'),
(21300, 'Beočin'),
(11000, 'Beograd'),
(18420, 'Blace'),
(15350, 'Bogatić'),
(16205, 'Bojnik'),
(19370, 'Boljevac'),
(19210, 'Bor'),
(37220, 'Brus'),
(17520, 'Bujanovac'),
(16215, 'Crna Trava'),
(32000, 'Čačak'),
(31310, 'Čajetina'),
(23320, 'Čoka'),
(37210, 'Ćićevac'),
(35230, 'Ćuprija'),
(35213, 'Despotovac'),
(18410, 'Doljevac'),
(18240, 'Gadžin Han'),
(35222, 'Glogovac'),
(12223, 'Golubac'),
(32300, 'Gornji Milanovac'),
(22320, 'Inđija'),
(22406, 'Irig'),
(32250, 'Ivanjica'),
(35000, 'Jagodina'),
(24420, 'Kanjiža'),
(23300, 'Kikinda'),
(19320, 'Kladovo'),
(34240, 'Knić'),
(19350, 'Knjaževac'),
(15220, 'Koceljeva'),
(31260, 'Kosjerić'),
(38210, 'Kosovo Polje'),
(38260, 'Kosovska Kamenica'),
(38220, 'Kosovska Mitrovica'),
(12208, 'Kostolac'),
(26210, 'Kovačica'),
(26220, 'Kovin'),
(34000, 'Kragujevac'),
(36000, 'Kraljevo'),
(15314, 'Krupanj'),
(37000, 'Kruševac'),
(12240, 'Kučevo'),
(25230, 'Kula'),
(18430, 'Kuršumlija'),
(14224, 'Lajkovac'),
(34221, 'Lapovo'),
(11550, 'Lazarevac'),
(16230, 'Lebane'),
(38218, 'Leposavić'),
(16000, 'Leskovac'),
(15300, 'Loznica'),
(32240, 'Lučani'),
(14240, 'Ljig'),
(15320, 'Ljubovija'),
(19250, 'Majdanpek'),
(24321, 'Mali Iđoš'),
(15318, 'Mali Zvornik'),
(12311, 'Malo Crniće'),
(16240, 'Medveđa'),
(35224, 'Medveđa'),
(37244, 'Medveđa'),
(18252, 'Merošina'),
(14242, 'Mionica'),
(11400, 'Mladenovac'),
(19300, 'Negotin'),
(18205, 'Niška Banja'),
(23218, 'Nova Crnja'),
(31320, 'Nova Varoš'),
(23272, 'Novi Bečej'),
(23330, 'Novi Kneževac'),
(36300, 'Novi Pazar'),
(21101, 'Novi Sad'),
(11500, 'Obrenovac'),
(25250, 'Odžaci'),
(26204, 'Opovo'),
(14253, 'Osečina'),
(26101, 'Pančevo'),
(35250, 'Paraćin'),
(22410, 'Pećinci'),
(21131, 'Petrovaradin'),
(18300, 'Pirot'),
(26360, 'Plandište'),
(12000, 'Požarevac'),
(31210, 'Požega'),
(17523, 'Preševo'),
(31330, 'Priboj'),
(31300, 'Prijepolje'),
(18400, 'Prokuplje'),
(18440, 'Rača'),
(36350, 'Raška'),
(37215, 'Ražanj'),
(35260, 'Rekovac'),
(22400, 'Ruma'),
(23240, 'Sečanj'),
(24400, 'Senta'),
(31205, 'Sevojno'),
(36310, 'Sjenica'),
(11300, 'Smederevo'),
(11420, 'Smederevska Palanka'),
(18230, 'Sokobanja'),
(25101, 'Sombor'),
(11450, 'Sopot'),
(21480, 'Srbobran'),
(21205, 'Sremski Karlovci'),
(22300, 'Stara Pazova'),
(34323, 'Stragari'),
(24000, 'Subotica'),
(17530, 'Surdulica'),
(35210, 'Svilajnac'),
(18360, 'Svrljig'),
(15000, 'Šabac'),
(22239, 'Šid'),
(38236, 'Štrpce'),
(21235, 'Temerin'),
(21240, 'Titel'),
(34310, 'Topola'),
(17525, 'Trgovište'),
(37240, 'Trstenik'),
(36320, 'Tutin'),
(14210, 'Ub'),
(31000, 'Užice'),
(14000, 'Valjevo'),
(37260, 'Varvarin'),
(11320, 'Velika Plana'),
(18403, 'Velika Plana'),
(12220, 'Veliko Gradište'),
(17510, 'Vladičin Han'),
(15225, 'Vladimirci'),
(16210, 'Vlasotince'),
(17501, 'Vranje'),
(17541, 'Vranjska Banja'),
(21460, 'Vrbas'),
(36210, 'Vrnjačka Banja'),
(26300, 'Vršac'),
(19000, 'Zaječar'),
(23101, 'Zrenjanin'),
(38228, 'Zubin Potok'),
(38227, 'Zvečan'),
(21230, 'Žabalj'),
(12374, 'Žabari'),
(12320, 'Žagubica'),
(23210, 'Žitište'),
(18412, 'Žitorađa');

-- GRUPE --
INSERT INTO grupe(naziv)
VALUES
('Menadžment i organizacija'),
('Elektrotehničko i računarsko inženjerstvo'),
('Arhitektura'),
('Biomedicinsko inženjerstvo'),
('Energetske tehnologije'),
('Geodetsko inženjerstvo'),
('Grafičko inženjerstvo i dizajn'),
('Građevinsko inženjerstvo'),
('Industrijsko inženjerstvo'),
('Inženjerstvo zaštite od katastrofalnih događaja i požara'),
('Inženjerstvo zaštite životne sredine i zaštite na radu'),
('Mašinsko inženjerstvo'),
('Mehatronika'),
('Računarska grafika'),
('Saobraćajno inženjerstvo'),
('Scenska arhitektura, tehnika i dizajn'),
('Jezik, književnost, kultura');

-- SMEROVI --

INSERT INTO smerovi(naziv, id_grupe) 
VALUES 
('Informacioni sistemi', '2'), 
('Informacione tehnologije', '2'), 
('Arhitektura', '3'), 
('Biomedicinsko inženjerstvo', '4'), 
('Energetika, elektronika i telekomunikacije', '2'), 
('Računarstvo i automatika', '2'), 
('Merenje i regulacija', '2'), 
('Primenjeno softversko inženjerstvo', '2'), 
('Softversko inženjerstvo i informacione tehnologije', '2'), 
('Informacioni inženjering', '2'), 
('Čiste energetske tehnologije', '5'), 
('Geodezija i geoinformatika', '6'), 
('Grafičko inženjerstvo i dizajn', '7'), 
('Građevinarstvo', '8'), 
('Industrijsko inženjerstvo', '9'), 
('Inženjerski menadžment', '9'), 
('Inženjerstvo informacionih sistema', '9'), 
('Upravljanje rizikom od katastrofalnih događaja i požara', '10'), 
('Inženjerstvo zaštite na radu', '11'), 
('Inženjerstvo zaštite životne sredine', '11'), 
('Proizvodno mašinstvo', '12'), 
('Mehanizacija i konstrukciono mašinstvo', '12'), 
('Energetika i procesna tehnika', '12'), 
('Tehnička mehanika i dizajn u tehnici', '12'), 
('Mehatronika', '13'),
('Finansijski menadžment', '1'), 
('Operacioni menadžment', '1'), 
('Projektni menadžment', '1');

-- PROFESORI --

INSERT INTO profesori(jmbg, ime, prezime, mejl, adresa, telefon, plata) 
VALUES 
('1507973785010', 'Slađana', 'Milojević', 'mdjordje@mts.rs', '8. mart 70', '0646850173', '67000'), 
('0303971780021', 'Jovica', 'Milojević', 'jovixkv@gmail.com', '8. mart 70', '0641979392', '83000'), 
('0405008780024', 'Đorđe', 'Milojević', 'djordjemilojevic2008@gmail.com', '8. mart 70', '0642723956', '56000'), 
('2301957780048', 'Janko', 'Filipović', 'jankof@gmail.com', 'Braće Pirić 9', '06556871239', '63000'), 
('2705985780014', 'Miloš', 'Veselić', 'veseli@gmail.com', 'I srpski ustanak 17', '0643175121', '91000'), 
('2710984782874', 'Miodrag', 'Lekić', 'lekicmiodrag84@gmail.com', 'Drvarska 32', '06095135726', '76000'), 
('1701985710114', 'Uroš', 'Bjelobrk', 'bjelibrk@gmail.com', 'Kralja Mihajla Zetskog 48', '0653928465', '59000'), 
('0305978780038', 'Ivan', 'Đekić', 'ivan78@gmail.com', 'Samaila 583', '06138416792', '69000');

-- PREDMETI --

INSERT INTO predmeti (naziv, id_smera, id_profesora, nedeljni_fond) 
VALUES 
('Osnove programiranja', '9', '2', '2'), 
('Algebra', '9', '1', '4'), 
('Arhitektura računara', '9', '4', '2'), 
('Sociologija tehnike', '9', '7', '2'), 
('Engleski jezik', '9', '3', '3'), 
('Objektno orijentisano programiranje 1', '9', '2', '3'), 
('Algoritmi i strukture podataka', '9', '5', '3'), 
('Uvod u softversko inženjerstvo', '9', '8', '3'), 
('Internet mreže', '9', '4', '3'), 
('Matematička analiza', '9', '1', '4'), 
('Diskretna matematika', '9', '1', '3'), 
('Objektno orijentisano programiranje 2', '9', '5', '2'), 
('Organizacija podataka', '9', '8', '2'), 
('Numerički algoritmi i numerički softver', '9', '4', '2'), 
('Baze podataka', '9', '5', '2'), 
('Veb programiranje', '9', '6', '2'), 
('Operativni sistemi', '9', '8', '2'), 
('Statistika', '9', '1', '3'), 
('Matematika 1', '26', '1', '4'), 
('Ekonomija', '26', '5', '4'), 
('Menadžment', '26', '7', '4'), 
('Osnove informaciono komunikacionih tehnologija', '26', '4', '4'), 
('Sociologija', '26', '7', '3'), 
('Psihologija', '26', '7', '3'), 
('Engleski jezik 1', '26', '3', '2'), 
('Matematika 2', '26', '1', '4'), 
('Osnovi organizacije', '26', '5', '4'), 
('Menadžment ljudskih resursa', '26', '2', '4'), 
('Ekonomika poslovanja i planiranje', '26', '6', '4');

-- ZAVISNOSTI -- 

INSERT INTO zavisnosti (id_predmeta_od, id_predmeta_ko) 
VALUES 
('1', '6'), 
('1', '7'), 
('1', '16'), 
('2', '11'), 
('2', '14'), 
('3', '9'), 
('6', '12'), 
('8', '17'), 
('10', '14'), 
('13', '15'), 
('19', '26'), 
('20', '29'), 
('21', '28');


-- STUDENTI --

INSERT INTO studenti (broj_indeksa, jmbg, ime, prezime, mejl, id_grada, id_smera) 
VALUES 
('1-2022', '1009004780028', 'Nikola', 'Rogonjić', 'nikolarogonjic14@gmail.com', '36000', '9'), 
('2-2022', '1210004785035', 'Ana', 'Luković', 'alukovic2004@gmail.com', '11000', '26'), 
('3-2022', '0510004780017', 'Stefan', 'Pejković', 'stefanpejkovic2004@gmail.com', '36000', '9'), 
('4-2022', '2004004785048', 'Sara', 'Spasojević', 'saraspasojevic7@gmail.com', '36000', '26'), 
('5-2022', '2304004785025', 'Anja', 'Đukić', 'anjadju2004@gmail.com', '11000', '26'), 
('6-2022', '2405005780028', 'Aleksandar', 'Temelkov', 'temelkovaleksa@gmail.com', '21101', '9'), 
('7-2022', '1106004785025', 'Jovana', 'Jaćović', 'jovanajacovic11@gmail.com', '19300', '26'), 
('8-2022', '0411004785061', 'Marija', 'Ljubić', 'ljubicmarija04@gmail.com', '34000', '26'), 
('9-2022', '1205004780056', 'Predrag', 'Babić', 'babicpedja37@gmail.com', '17541', '9'),
('10-2022', '1606003780014', 'Aleksa', 'Milić', 'aleksamilickv@gmail.com', '36000', '9'), 
('11-2022', '2206004780013', 'Strahinja', 'Sretović', 'strahinjasretovic04@gmail.com', '21101', '9'), 
('12-2022', '0807005780013', 'Viktor', 'Kundović', 'viktor.vico@gmail.com', '32250', '9'),
('13-2022', '1408004924978', 'Andrija', 'Baščarević', 'bascarevic.andrija22@gmail.com', '21101', '9'),
('14-2022', '1003004780038', 'Jovan', 'Jovanović', 'jovqnovicc@gmail.com', '36000', '26'), 
('15-2022', '0201005780034', 'Mihajlo', 'Anđelković', 'mihajlomikiandjelkovic5@gmail.com', '36000', '9'),
('16-2022', '2501005780019', 'Vojin', 'Šundović', 'vojinsundovic@gmail.com', '36000', '9');


-- SLUSANANJA --

INSERT INTO slusanja (id_predmeta, broj_indeksa, zavrseno) 
VALUES 
('1', '1-2022', '0'), 
('1', '10-2022', '0'), 
('1', '11-2022', '0'), 
('1', '12-2022', '0'), 
('1', '13-2022', '0'), 
('1', '15-2022', '0'),
('1', '16-2022', '0'),
('1', '3-2022', '0'), 
('1', '6-2022', '0'), 
('1', '9-2022', '0'), 
('2', '1-2022', '0'), 
('2', '10-2022', '0'), 
('2', '11-2022', '0'), 
('2', '12-2022', '0'), 
('2', '13-2022', '0'), 
('2', '15-2022', '0'), 
('2', '16-2022', '0'),
('2', '3-2022', '0'), 
('2', '6-2022', '0'), 
('2', '9-2022', '0'), 
('3', '1-2022', '0'), 
('3', '10-2022', '0'), 
('3', '11-2022', '0'), 
('3', '12-2022', '0'), 
('3', '13-2022', '0'), 
('3', '15-2022', '0'),
('3', '16-2022', '0'), 
('3', '3-2022', '0'),
('3', '6-2022', '0'), 
('3', '9-2022', '0'), 
('4', '10-2022', '0'), 
('4', '11-2022', '0'), 
('4', '13-2022', '0'), 
('4', '15-2022', '0'), 
('5', '1-2022', '0'), 
('5', '11-2022', '0'), 
('5', '12-2022', '0'), 
('5', '13-2022', '0'), 
('5', '15-2022', '0'), 
('5', '3-2022', '0'), 
('5', '6-2022', '0'), 
('5', '9-2022', '0'), 
('8', '1-2022', '0'), 
('8', '10-2022', '0'), 
('8', '11-2022', '0'), 
('8', '12-2022', '0'), 
('8', '13-2022', '0'), 
('8', '15-2022', '0'), 
('8', '3-2022', '0'), 
('8', '6-2022', '0'), 
('8', '9-2022', '0'), 
('10', '13-2022', '0'), 
('10', '15-2022', '0'),
('10', '16-2022', '0'),
('10', '9-2022', '0'), 
('13', '9-2022', '0'), 
('19', '14-2022', '0'), 
('19', '2-2022', '0'), 
('19', '4-2022', '0'), 
('19', '5-2022', '0'), 
('19', '7-2022', '0'), 
('19', '8-2022', '0'), 
('20', '14-2022', '0'), 
('20', '2-2022', '0'), 
('20', '4-2022', '0'), 
('20', '5-2022', '0'), 
('20', '7-2022', '0'), 
('20', '8-2022', '0'), 
('21', '14-2022', '0'), 
('21', '2-2022', '0'), 
('21', '4-2022', '0'), 
('21', '5-2022', '0'), 
('21', '7-2022', '0'), 
('21', '8-2022', '0'), 
('22', '2-2022', '0'), 
('22', '5-2022', '0'), 
('22', '7-2022', '0'), 
('22', '8-2022', '0'), 
('23', '14-2022', '0'), 
('23', '8-2022', '0'), 
('24', '14-2022', '0'), 
('24', '4-2022', '0'), 
('24', '7-2022', '0'), 
('24', '8-2022', '0'), 
('25', '14-2022', '0'), 
('25', '2-2022', '0'), 
('25', '4-2022', '0'), 
('25', '5-2022', '0'), 
('25', '7-2022', '0'), 
('25', '8-2022', '0'), 
('27', '5-2022', '0'), 
('27', '7-2022', '0'), 
('27', '8-2022', '0');


-- ISPITI --

INSERT INTO ispiti (id_predmeta, datum)
VALUES 
('2', '2022-06-14 14:53:00'), 
('2', '2022-07-14 14:53:26'), 
('10', '2022-06-15 14:53:42'), 
('10', '2022-07-15 14:53:48'), 
('11', '2022-06-16 14:54:08'), 
('11', '2022-07-16 14:54:16'), 
('18', '2022-06-19 14:54:29'), 
('18', '2022-07-19 14:54:37'), 
('1', '2022-06-20 14:55:10'), 
('1', '2022-07-20 14:55:26'), 
('6', '2022-06-21 14:55:36'), 
('6', '2022-07-21 14:55:42'), 
('5', '2022-06-22 14:56:12'), 
('5', '2022-07-22 14:56:18'), 
('3', '2022-06-26 14:56:48'), 
('3', '2022-07-26 14:57:15'), 
('9', '2022-06-27 14:57:28'), 
('9', '2022-07-27 14:57:35'), 
('14', '2022-06-28 14:58:06'), 
('14', '2022-07-28 14:58:16'), 
('7', '2022-06-29 14:58:41'), 
('7', '2022-07-29 14:58:57'), 
('15', '2022-06-30 14:59:24'), 
('15', '2022-07-30 14:59:33'), 
('16', '2022-07-04 15:00:01'), 
('16', '2022-08-04 15:00:12'), 
('4', '2022-07-05 15:00:35'), 
('4', '2022-08-05 15:00:45'), 
('8', '2022-07-11 15:01:16'), 
('8', '2022-08-11 15:01:32'), 
('13', '2022-07-12 15:01:46'), 
('13', '2022-08-12 15:02:41'), 
('17', '2022-07-15 15:02:54'), 
('17', '2022-08-15 15:03:06'), 
('19', '2022-06-14 15:03:33'), 
('19', '2022-07-14 15:03:41'), 
('26', '2022-06-15 15:04:32'), 
('26', '2022-07-15 15:04:39'), 
('28', '2022-06-20 15:05:01'), 
('28', '2022-07-20 15:06:03'), 
('25', '2022-06-21 15:06:33'), 
('25', '2022-07-21 15:06:40'), 
('22', '2022-06-22 15:07:13'), 
('22', '2022-07-22 15:07:26'), 
('20', '2022-06-27 15:07:48'), 
('20', '2022-07-27 15:07:59'), 
('27', '2022-06-28 15:08:15'), 
('27', '2022-07-28 15:08:23'), 
('29', '2022-06-29 15:08:45'), 
('29', '2022-07-29 15:09:03'), 
('21', '2022-07-04 15:09:34'), 
('21', '2022-08-04 15:09:53'), 
('23', '2022-07-05 15:10:06'), 
('23', '2022-08-05 15:10:12'), 
('24', '2022-07-11 15:10:24'), 
('24', '2022-08-11 15:10:39');

-- ADMINISTRATORI --

INSERT INTO admini (jmbg, ime, prezime, mejl, adresa, telefon) 
VALUES 
('3105004780024', 'Mihajlo', 'Milojevic', 'milojevicm374@gmail.com', '8. mart 70', '0649781191');