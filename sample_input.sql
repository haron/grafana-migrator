0|display_name|varchar(64)|1||0
1|name|varchar(64)|1||0
2|local_site_id|integer|0||0
3|incoming_request_count|integer|0||0
4|invite_only|bool|1||0
5|id|integer|1||1
6|mailing_list|varchar(75)|1||0
7|visible|bool|1||0
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION; 
CREATE TABLE "reviews_group"("display_name" varchar(64) NOT NULL, "name" varchar(64) NOT NULL, "local_site_id" integer NULL, "incoming_request_count" integer NULL, "invite_only" bool NOT NULL, "id" integer NOT NULL UNIQUE PRIMARY KEY, "mailing_list" varchar(75) NOT NULL, "visible" bool NOT NULL);
INSERT INTO "reviews_group" VALUES('Developers','developers',NULL,127,0,1,'',1);
INSERT INTO "reviews_group" VALUES('Testers','testers',NULL,2,0,2,'',1);
INSERT INTO "reviews_group" VALUES('QA','qa',NULL,1,0,3,'',1);
INSERT INTO "reviews_group" VALUES('Release Engineers','releng',NULL,7,0,4,'',1);
INSERT INTO "reviews_group" VALUES('Managers','mgrs',NULL,1,0,5,'',1);
COMMIT;