-- MySQL dump 10.13  Distrib 8.0.40, for Linux (x86_64)
--
-- Host: localhost    Database: STUDENTS
-- ------------------------------------------------------
-- Server version	8.0.40-0ubuntu0.24.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `STUDENTS`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `STUDENTS` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `STUDENTS`;

--
-- Table structure for table `students`
--

DROP TABLE IF EXISTS `students`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `students` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `address` varchar(255) NOT NULL,
  `city` varchar(255) NOT NULL,
  `state` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `phone` varchar(100) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `students`
--

LOCK TABLES `students` WRITE;
/*!40000 ALTER TABLE `students` DISABLE KEYS */;
INSERT INTO `students` VALUES (1, 'John Doe', '123 Main St', 'New York', 'NY', 'johndoe@example.com', '5551234567'),
(2, 'Jane Smith', '456 Elm St', 'Los Angeles', 'CA', 'janesmith@example.com', '5559876543'),
(3, 'Sam Johnson', '789 Oak St', 'Chicago', 'IL', 'samjohnson@example.com', '5552345678'),
(4, 'Alice Brown', '321 Pine St', 'Houston', 'TX', 'alicebrown@example.com', '5553456789'),
(5, 'Bob White', '654 Cedar St', 'Phoenix', 'AZ', 'bobwhite@example.com', '5554567890'),
(6, 'Emily Davis', '987 Maple St', 'Philadelphia', 'PA', 'emilydavis@example.com', '5555678901'),
(7, 'Chris Green', '741 Spruce St', 'San Antonio', 'TX', 'chrisgreen@example.com', '5556789012'),
(8, 'Laura Blue', '852 Ash St', 'San Diego', 'CA', 'laurablue@example.com', '5557890123'),
(9, 'Michael Black', '963 Walnut St', 'Dallas', 'TX', 'michaelblack@example.com', '5558901234'),
(10, 'Sarah Gray', '159 Birch St', 'San Jose', 'CA', 'sarahgray@example.com', '5559012345'),
(11, 'Daniel Gold', '753 Redwood St', 'Austin', 'TX', 'danielgold@example.com', '5550123456'),
(12, 'Olivia Silver', '456 Cypress St', 'Jacksonville', 'FL', 'oliviasilver@example.com', '5551238901'),
(13, 'Ethan Copper', '123 Magnolia St', 'Columbus', 'OH', 'ethancopper@example.com', '5552349012'),
(14, 'Sophia Violet', '987 Dogwood St', 'Charlotte', 'NC', 'sophiaviolet@example.com', '5553450123'),
(15, 'Liam Bronze', '654 Hickory St', 'Indianapolis', 'IN', 'liambronze@example.com', '5554561234'),
(16, 'Emma Teal', '741 Palm St', 'San Francisco', 'CA', 'emmateal@example.com', '5555672345'),
(17, 'Noah Indigo', '852 Willow St', 'Fort Worth', 'TX', 'noahindigo@example.com', '5556783456'),
(18, 'Ava Crimson', '963 Aspen St', 'Seattle', 'WA', 'avacrimson@example.com', '5557894567'),
(19, 'James Scarlet', '159 Poplar St', 'Denver', 'CO', 'jamesscarlet@example.com', '5558905678'),
(20, 'Isabella Amber', '753 Fir St', 'Washington', 'DC', 'isabellaamber@example.com', '5559016789');

/*!40000 ALTER TABLE `students` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2024-12-15  3:54:58
