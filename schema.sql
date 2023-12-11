DROP SCHEMA IF EXISTS ArborDB CASCADE;
CREATE SCHEMA ArborDB;
SET SCHEMA 'arbordb';

CREATE DOMAIN RAUNKIAER_DOM AS varchar(16)
CHECK (VALUE IN ('Phanerophytes', 'Epiphytes', 'Chamaephytes', 'Hemicryptophytes',
                'Cryptophytes', 'Therophytes', 'Aerophytes')
);

CREATE DOMAIN RANK_DOM AS varchar(10)
CHECK (VALUE IN ( 'Lead', 'Senior', 'Associate')
);


CREATE TABLE FOREST (
    forest_no   int      NOT NULL,
    name        varchar(30),
    area        int         NOT NULL,
    acid_level  real,
    MBR_XMin    real        NOT NULL,
    MBR_XMax    real        NOT NULL,
    MBR_YMin    real        NOT NULL,
    MBR_YMax    real        NOT NULL,
    CONSTRAINT PK_FOREST PRIMARY KEY (forest_no)
);

CREATE TABLE WORKER (
    ssn             int         NOT NULL,
    first_name      varchar(30) NOT NULL,
    last_name       varchar(30) NOT NULL,
    middle_initial  char(1),
    rank            RANK_DOM,
    CONSTRAINT PK_WORKER PRIMARY KEY (ssn)
);

CREATE TABLE PHONE (
    worker             int,
    type               varchar(30),
    work_phone_number  varchar(16),
    CONSTRAINT PK_PHONE PRIMARY KEY (work_phone_number, worker),
    CONSTRAINT FK_PHONE FOREIGN KEY (worker) REFERENCES WORKER (ssn)
);

CREATE TABLE SENSOR (
    sensor_id       int         NOT NULL,
    last_charged    timestamp,
    energy          int         NOT NULL,
    last_read       timestamp,
    X               real,
    Y               real,
    maintainer_id   int         NOT NULL,
    CONSTRAINT PK_SENSOR PRIMARY KEY (sensor_id),
    CONSTRAINT FK_SENSOR FOREIGN KEY (maintainer_id) REFERENCES WORKER (ssn)

);

CREATE TABLE REPORT (
    sensor_id       int         NOT NULL,
    report_time     timestamp   NOT NULL,
    temperature     real        NOT NULL,
    CONSTRAINT PK_REPORT PRIMARY KEY (sensor_id, report_time),
    CONSTRAINT FK_REPORT FOREIGN KEY (sensor_id) REFERENCES SENSOR (sensor_id) ON DELETE CASCADE
);

CREATE TABLE STATE (
    name            varchar(30) UNIQUE,
    abbreviation    char(2)     NOT NULL,
    area            int,
    population      int,
    MBR_XMin        real,
    MBR_XMax        real,
    MBR_YMin        real,
    MBR_YMax        real,
    CONSTRAINT PK_STATE PRIMARY KEY (abbreviation)
);

CREATE TABLE EMPLOYED (
    state       varchar(2),
    worker      int,
    CONSTRAINT PK_EMPLOYED PRIMARY KEY (state, worker),
    CONSTRAINT FK_EMPLOYED_1 FOREIGN KEY (state) REFERENCES STATE (abbreviation),
    CONSTRAINT FK_EMPLOYED_2 FOREIGN KEY (worker) REFERENCES WORKER (ssn)
);

CREATE TABLE TREE_COMMON_NAME (
    genus           varchar(30),
    epithet         varchar(30),
    common_name     varchar(30),
    CONSTRAINT PK_COMMON_NAME PRIMARY KEY (common_name)
);

CREATE TABLE TREE_SPECIES (
    genus               varchar(30)     NOT NULL,
    epithet             varchar(30)     NOT NULL,
    ideal_temperature   real,
    largest_height      real,
    raunkiaer_life_form RAUNKIAER_DOM ,
    CONSTRAINT PK_SPECIES PRIMARY KEY (genus, epithet)
);

CREATE TABLE COVERAGE (
    forest_no       int,
    state           varchar(30),
    percentage      real,
    area            int,
    CONSTRAINT PK_COVERAGE PRIMARY KEY (forest_no, state),
    CONSTRAINT FK_COVERAGE_1 FOREIGN KEY (forest_no) REFERENCES FOREST (forest_no) ON DELETE CASCADE,
    CONSTRAINT FK_COVERAGE_2 FOREIGN KEY (state) REFERENCES STATE (name) ON DELETE CASCADE
);

CREATE TABLE FOUND_IN (
    forest_no   int,
    genus       varchar(30),
    epithet     varchar(30),
    CONSTRAINT PK_FOUND_IN PRIMARY KEY (forest_no, genus, epithet),
    CONSTRAINT FK_FOUND_IN_1 FOREIGN KEY (forest_no) REFERENCES FOREST (forest_no),
    CONSTRAINT FK_FOUND_IN_2 FOREIGN KEY (genus, epithet) REFERENCES TREE_SPECIES (genus, epithet)
);

CREATE TABLE CLOCK (
    synthetic_time timestamp,
    CONSTRAINT PK_CLOCK PRIMARY KEY (synthetic_time)
);
INSERT INTO clock values (current_timestamp);
