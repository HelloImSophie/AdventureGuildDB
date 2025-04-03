-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Maj 20, 2024 at 10:17 PM
-- Wersja serwera: 10.4.32-MariaDB
-- Wersja PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `adventurersguild`
--

DELIMITER $$
--
-- Procedury
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `demote` (IN `advID` INT)   BEGIN
UPDATE adventurers
SET adventurers.grade = adventurers.grade - 1
WHERE adventurers.id = advID;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `DoneQuest` (IN `teamID` INT)   BEGIN
	DECLARE qID INT DEFAULT (SELECT teams.ongoingQuestID FROM teams WHERE teams.ID = teamID);

	UPDATE quests
    SET quests.status = 3, quests.date = CURRENT_DATE
    WHERE quests.ID = qID;
	
    UPDATE treasure
    SET treasure.quantity = treasure.quantity - (SELECT quests.reward FROM quests WHERE quests.ID = qID)
    WHERE treasure.itemID = 1;
    
	UPDATE teams
    SET teams.ongoingQuestID = 0
    WHERE teams.ID = teamID;    
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `failQuest` (IN `teamID` INT)   BEGIN
	UPDATE quests
    SET quests.status = 3, quests.date = CURRENT_DATE
    WHERE quests.ID = (SELECT teams.ongoingQuestID FROM teams WHERE teams.ID = teamID);
	
	UPDATE teams
    SET teams.ongoingQuestID = 0
    WHERE teams.ID = teamID;    
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ListRescue` ()   BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE questDesc VARCHAR(255);
    DECLARE finalDesc VARCHAR(255);
    DECLARE questGrade VARCHAR(1);
    DECLARE questID, questType, questStatus, questNumPeople, questDungID INT;
    DECLARE questReward FLOAT;
    DECLARE questDate DATE;
    DECLARE cur CURSOR FOR SELECT * FROM quests;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO questID, questDesc, questType, questStatus, questGrade, questNumPeople, questReward, questDungID, questDate;
        IF done THEN
            LEAVE read_loop;
        END IF;

        IF questType = 1 AND questStatus = 2 AND questDate < CURRENT_DATE THEN
            SET finalDesc = CONCAT(questDesc, ' - Misja Ratunkowa');
            INSERT INTO adventurersguild.quests (`description`, `type`, `status`, `minimalGrade`, `minimalNumberOfPeople`, `reward`, `dungeonID`, `date`)
            VALUES (finalDesc, '1', '1', questGrade, questNumPeople, questReward + 100 * questNumPeople, questDungID, DATE_ADD(questDate, INTERVAL 3 YEAR));
        END IF;
    END LOOP;

    CLOSE cur;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `promote` (IN `advID` INT)   BEGIN
UPDATE adventurers
SET adventurers.grade = adventurers.grade + 1
WHERE adventurers.id = advID;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `takeQuest` (IN `teamID` INT, IN `questID` INT, IN `timetocom` DATE)   BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE ID INT;
    DECLARE grade CHAR(1);
    DECLARE pplCount INT DEFAULT 0;
    DECLARE ValidFlag TINYINT DEFAULT TRUE;
    DECLARE message VARCHAR(255);

    DECLARE cur CURSOR FOR
        SELECT teamsmembership.AdventerurerID, adventurers.grade
        FROM teamsmembership
        JOIN adventurers ON adventurers.id =teamsmembership.AdventerurerID
        WHERE teamsmembership.TeamID = teamID;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO ID, grade;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET pplCount = pplCount + 1;

        IF grade < (SELECT quests.minimalGrade FROM quests WHERE quests.ID = questID) THEN
            SET ValidFlag = FALSE;
            SET message = 'Too low grade';
        END IF;
    END LOOP;

    CLOSE cur;

    IF pplCount < (SELECT quests.minimalNumberOfPeople FROM quests WHERE quests.ID = questID) THEN
        SET ValidFlag = FALSE;
        SET message = 'Not enough members';
    END IF;

    IF (SELECT quests.status FROM quests WHERE quests.ID = questID) != 1 THEN
        SET ValidFlag = FALSE;
        SET message = 'Quest is not open';
    END IF;
    
    IF (SELECT teams.ongoingQuestID FROM teams WHERE teams.ID = teamID) != 0 THEN
        SET ValidFlag = FALSE;
        SET message = 'Party is on another quest';
    END IF;

    IF ValidFlag THEN
        UPDATE quests
        SET quests.status = 2, quests.date = timetocom 
        WHERE quests.ID = questID;
        
        UPDATE teams
        SET teams.ongoingQuestID = questID
        WHERE teams.ID = teamID;
        SET message = 'Quest accepted';
    END IF;

    SELECT message AS status_message;

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `adventurers`
--

CREATE TABLE `adventurers` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `class` varchar(63) NOT NULL,
  `grade` int(11) NOT NULL,
  `level` int(11) NOT NULL,
  `expirience` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `adventurers`
--

INSERT INTO `adventurers` (`id`, `name`, `class`, `grade`, `level`, `expirience`) VALUES
(1, 'Andrzej', 'Biedak', 1, 3, 0),
(2, 'Le\'Gard', 'Rycerz', 1, 13, 5),
(3, 'Arthur', 'Łotrzyk', 1, 5, 300),
(4, 'Mazak', 'Krwiohekser', 1, 2, 10),
(5, 'Nazyrjan', 'Szczurołak', 1, 4, 9),
(6, 'Wirgiliusz', 'Kucharz Bitewny', 1, 5, 50);

--
-- Wyzwalacze `adventurers`
--
DELIMITER $$
CREATE TRIGGER `trgBeforeUpdate` BEFORE UPDATE ON `adventurers` FOR EACH ROW BEGIN
    DECLARE lv_diff INT;
    SET lv_diff = NEW.level - OLD.level;
    
    WHILE NEW.expirience > 999 DO
        SET lv_diff = lv_diff + 1;
        SET NEW.expirience = NEW.expirience - 1000;
    END WHILE;

    SET NEW.level = OLD.level + lv_diff;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `dungeons`
--

CREATE TABLE `dungeons` (
  `ID` int(11) NOT NULL,
  `description` varchar(255) NOT NULL,
  `status` int(11) NOT NULL COMMENT '1 - unexplored\r\n2 - partialy exlored\r\n3 - explored'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `dungeons`
--

INSERT INTO `dungeons` (`ID`, `description`, `status`) VALUES
(0, 'Misja Bez Podziemi', 0),
(1, 'Pear and Anger', 2),
(2, 'Tawerniana Piwnica', 3);

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `quests`
--

CREATE TABLE `quests` (
  `ID` int(11) NOT NULL,
  `description` varchar(255) NOT NULL,
  `type` int(11) NOT NULL COMMENT '1 - Insured\r\n2 - Uninsured',
  `status` int(11) NOT NULL COMMENT '1 - open\r\n2 - ongoing\r\n3 - closed',
  `minimalGrade` int(11) NOT NULL,
  `minimalNumberOfPeople` int(11) NOT NULL,
  `reward` float NOT NULL,
  `dungeonID` int(11) NOT NULL,
  `date` date NOT NULL COMMENT '1 - expiration date\r\n2 - time to complete\r\n3 - date of completion'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `quests`
--

INSERT INTO `quests` (`ID`, `description`, `type`, `status`, `minimalGrade`, `minimalNumberOfPeople`, `reward`, `dungeonID`, `date`) VALUES
(1, 'eksploracja podziemi', 1, 3, 1, 1, 400, 1, '2024-05-17'),
(2, 'Misja ratownicza -odnaleść Le\'Garda', 1, 1, 1, 1, 400, 1, '2024-05-21'),
(3, 'Eskorta Kupiecka', 2, 2, 1, 2, 250, 0, '2024-05-31'),
(4, 'Eksterminacja Szczurów', 1, 2, 1, 1, 50, 2, '2024-05-15');

-- --------------------------------------------------------

--
-- Zastąpiona struktura widoku `readableadventurers`
-- (See below for the actual view)
--
CREATE TABLE `readableadventurers` (
`id` int(11)
,`name` varchar(255)
,`class` varchar(63)
,`salary_grade` varchar(7)
,`level` int(11)
,`expirience` int(11)
);

-- --------------------------------------------------------

--
-- Zastąpiona struktura widoku `readablequests`
-- (See below for the actual view)
--
CREATE TABLE `readablequests` (
`ID` int(11)
,`description` varchar(255)
,`insurence` varchar(9)
,`stat` varchar(7)
,`minimalGrade` varchar(7)
,`minimalNumberOfPeople` int(11)
,`reward` float
,`dungeonName` varchar(255)
,`date` date
);

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `teams`
--

CREATE TABLE `teams` (
  `ID` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `ongoingQuestID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `teams`
--

INSERT INTO `teams` (`ID`, `name`, `ongoingQuestID`) VALUES
(1, 'Andrzej Biedak Solo Leveling', 4),
(2, 'Salami Squad', 3),
(3, 'ekskluzywna kompania magiczna', 0),
(4, 'Samotna Wojażeria Le\'Garda', 0);

-- --------------------------------------------------------

--
-- Zastąpiona struktura widoku `teamsandmembers`
-- (See below for the actual view)
--
CREATE TABLE `teamsandmembers` (
`name` varchar(255)
,`members` mediumtext
);

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `teamsmembership`
--

CREATE TABLE `teamsmembership` (
  `ID` int(11) NOT NULL,
  `AdventerurerID` int(11) NOT NULL,
  `TeamID` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `teamsmembership`
--

INSERT INTO `teamsmembership` (`ID`, `AdventerurerID`, `TeamID`) VALUES
(1, 1, 1),
(2, 6, 2),
(3, 3, 2),
(4, 4, 2),
(5, 5, 2),
(6, 4, 3),
(7, 2, 4);

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `treasure`
--

CREATE TABLE `treasure` (
  `itemID` int(11) NOT NULL,
  `description` varchar(127) NOT NULL,
  `quantity` int(11) NOT NULL,
  `value` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `treasure`
--

INSERT INTO `treasure` (`itemID`, `description`, `quantity`, `value`) VALUES
(1, 'Złoto', 937, 1),
(2, 'Pochodnia', 20, 2),
(3, 'Racje Żywnościowe', 30, 10),
(4, 'Mikstura Zdrowia', 34, 5),
(5, 'Mikstura Many', 42, 4),
(6, 'Zwój Wskrzeszenia', 4, 500);

-- --------------------------------------------------------

--
-- Struktura widoku `readableadventurers`
--
DROP TABLE IF EXISTS `readableadventurers`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `readableadventurers`  AS SELECT `adventurers`.`id` AS `id`, `adventurers`.`name` AS `name`, `adventurers`.`class` AS `class`, CASE WHEN `adventurers`.`grade` = 7 THEN 'S' WHEN `adventurers`.`grade` = 6 THEN 'A' WHEN `adventurers`.`grade` = 5 THEN 'B' WHEN `adventurers`.`grade` = 4 THEN 'C' WHEN `adventurers`.`grade` = 3 THEN 'D' WHEN `adventurers`.`grade` = 2 THEN 'E' WHEN `adventurers`.`grade` = 1 THEN 'F' ELSE 'Unknown' END AS `salary_grade`, `adventurers`.`level` AS `level`, `adventurers`.`expirience` AS `expirience` FROM `adventurers` ;

-- --------------------------------------------------------

--
-- Struktura widoku `readablequests`
--
DROP TABLE IF EXISTS `readablequests`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `readablequests`  AS SELECT `quests`.`ID` AS `ID`, `quests`.`description` AS `description`, CASE WHEN `quests`.`type` = 1 THEN 'insured' WHEN `quests`.`type` = 2 THEN 'uninsured' ELSE 'Unknown' END AS `insurence`, CASE WHEN `quests`.`status` = 1 THEN 'open' WHEN `quests`.`status` = 2 THEN 'ongoing' WHEN `quests`.`status` = 3 THEN 'closed' ELSE 'Unknown' END AS `stat`, CASE WHEN `quests`.`minimalGrade` = 7 THEN 'S' WHEN `quests`.`minimalGrade` = 6 THEN 'A' WHEN `quests`.`minimalGrade` = 5 THEN 'B' WHEN `quests`.`minimalGrade` = 4 THEN 'C' WHEN `quests`.`minimalGrade` = 3 THEN 'D' WHEN `quests`.`minimalGrade` = 2 THEN 'E' WHEN `quests`.`minimalGrade` = 1 THEN 'F' ELSE 'Unknown' END AS `minimalGrade`, `quests`.`minimalNumberOfPeople` AS `minimalNumberOfPeople`, `quests`.`reward` AS `reward`, `dungeons`.`description` AS `dungeonName`, `quests`.`date` AS `date` FROM (`quests` join `dungeons` on(`dungeons`.`ID` = `quests`.`dungeonID`)) ;

-- --------------------------------------------------------

--
-- Struktura widoku `teamsandmembers`
--
DROP TABLE IF EXISTS `teamsandmembers`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `teamsandmembers`  AS SELECT `teams`.`name` AS `name`, group_concat(`adventurers`.`name` separator ',') AS `members` FROM ((`teamsmembership` join `teams` on(`teams`.`ID` = `teamsmembership`.`TeamID`)) join `adventurers` on(`adventurers`.`id` = `teamsmembership`.`AdventerurerID`)) GROUP BY `teams`.`ID` ;

--
-- Indeksy dla zrzutów tabel
--

--
-- Indeksy dla tabeli `adventurers`
--
ALTER TABLE `adventurers`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `dungeons`
--
ALTER TABLE `dungeons`
  ADD PRIMARY KEY (`ID`);

--
-- Indeksy dla tabeli `quests`
--
ALTER TABLE `quests`
  ADD PRIMARY KEY (`ID`);

--
-- Indeksy dla tabeli `teams`
--
ALTER TABLE `teams`
  ADD PRIMARY KEY (`ID`);

--
-- Indeksy dla tabeli `teamsmembership`
--
ALTER TABLE `teamsmembership`
  ADD PRIMARY KEY (`ID`);

--
-- Indeksy dla tabeli `treasure`
--
ALTER TABLE `treasure`
  ADD PRIMARY KEY (`itemID`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `adventurers`
--
ALTER TABLE `adventurers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `dungeons`
--
ALTER TABLE `dungeons`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `quests`
--
ALTER TABLE `quests`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `teams`
--
ALTER TABLE `teams`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `teamsmembership`
--
ALTER TABLE `teamsmembership`
  MODIFY `ID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `treasure`
--
ALTER TABLE `treasure`
  MODIFY `itemID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

DELIMITER $$
--
-- Events
--
CREATE DEFINER=`root`@`localhost` EVENT `DailyEvent` ON SCHEDULE EVERY 1 DAY STARTS '2024-05-21 00:00:00' ON COMPLETION NOT PRESERVE ENABLE DO CALL listRescue()$$

DELIMITER ;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
