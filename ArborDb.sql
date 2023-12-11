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

--check_employment() trigger
CREATE OR REPLACE FUNCTION check_employment()
RETURNS TRIGGER AS $$

    DECLARE employee        int;
    DECLARE overlap_state   varchar(2);
    BEGIN
        SELECT abbreviation INTO overlap_state FROM arbordb.STATE
            WHERE MBR_XMin < NEW.X AND MBR_XMax > NEW.X AND MBR_YMin < NEW.Y AND MBR_YMax > NEW.Y;

        IF NOT EXISTS (
            SELECT worker FROM arbordb.EMPLOYED
            WHERE arbordb.EMPLOYED.state = overlap_state
        )THEN
            RAISE NOTICE 'Incorrect maintainer--> %', employee
            USING HINT = 'The new maintainer of this sensor is not employed by a state which covers the
                            sensor. This operation has been reverted';
            RETURN NULL;
        end if;

    RETURN NEW;
    end; $$ LANGUAGE PLPGSQL;

DROP TRIGGER IF EXISTS checkMaintainerEmployment on SENSOR;
CREATE TRIGGER checkMaintainerEmployment
    BEFORE INSERT OR UPDATE ON SENSOR
    FOR EACH ROW
    EXECUTE FUNCTION check_employment();



--insert_coverage() trigger
CREATE OR REPLACE FUNCTION insert_coverage()
RETURNS TRIGGER AS $$
    DECLARE row             record;
    DECLARE Forest_Xmin     integer;
    DECLARE Forest_Xmax     integer;
    DECLARE Forest_Ymin     integer;
    DECLARE Forest_Ymax     integer;
    DECLARE state_name      varchar(30);
    DECLARE Forest_Num      integer;
    DECLARE x_dist          integer;
    DECLARE y_dist          integer;
    DECLARE coverage_area   integer;
    DECLARE state_area      real;
    DECLARE cov_percentage  real;
    BEGIN

    --get attributes of forest to be inserted
    Forest_Num  := new.forest_no;
    Forest_Xmax := new.mbr_xmax;
    Forest_Xmin := new.mbr_xmin;
    Forest_Ymax := new.mbr_ymax;
    Forest_Ymin := new.mbr_ymin;

    --loop through states and for each state where overlap occurs, insert into coverage
    for row in SELECT * FROM arbordb.STATE
        loop
            IF NOT(row.mbr_xmin > Forest_Xmax OR row.mbr_xmax < Forest_Xmin OR row.mbr_ymin > Forest_Ymax OR row.mbr_ymax < Forest_Ymin) THEN
                state_name      := row.name;
                state_area      := row.area;
                x_dist          := least(Forest_Xmax, row.mbr_xmax) - least(Forest_Xmin, row.mbr_xmin);
                y_dist          := least(Forest_Ymax, row.mbr_ymax) - least(Forest_Ymin, row.mbr_ymin);
                coverage_area   := x_dist * y_dist;
                cov_percentage  := (coverage_area / state_area) * 100;

                INSERT INTO arbordb.COVERAGE values(Forest_Num, state_name, cov_percentage, coverage_area);

            END IF;
        end loop;

    RETURN NEW;
    end; $$ LANGUAGE PLPGSQL;

DROP TRIGGER IF EXISTS addForestCoverage on FOREST;
CREATE TRIGGER addForestCoverage
    AFTER INSERT ON arbordb.FOREST
    FOR EACH ROW
    EXECUTE FUNCTION insert_coverage();

--Data Manipulation Operations

--#1 addForest
CREATE OR REPLACE FUNCTION arbordb.addForest (name varchar(30), area int, acid_level real, MBR_XMin real, MBR_XMax real, MBR_YMin real, MBR_YMax real)
RETURNS void AS $$
    DECLARE high_forest_no int;
BEGIN

    SELECT MAX(forest_no) INTO high_forest_no FROM arbordb.FOREST;
    IF (high_forest_no IS NULL)
        THEN high_forest_no := 0;
    END IF;
    INSERT INTO arbordb.FOREST VALUES (high_forest_no+1, name, area, acid_level, MBR_Xmin, MBR_Xmax, MBR_Ymin, MBR_YMax);
    RETURN;

END;
$$ LANGUAGE PLPGSQL;


--#2 addTreeSpecies
CREATE OR REPLACE FUNCTION arbordb.addTreeSpecies (genus varchar(30), epithet varchar(30), ideal_temp real, largest_height real, life_form RAUNKIAER_DOM)
RETURNS void AS $$
BEGIN
    INSERT INTO arbordb.TREE_SPECIES VALUES(genus, epithet, ideal_temp, largest_height, life_form);
    RETURN;

END;
$$ LANGUAGE PLPGSQL;


--#3 addSpeciesToForest
CREATE OR REPLACE FUNCTION arbordb.addSpeciesToForest(forest_no int, genus varchar(30), epithet varchar(30))
RETURNS void AS $$
BEGIN
    INSERT INTO arbordb.FOUND_IN VALUES(forest_no, genus, epithet);
    RETURN;
END;
$$ LANGUAGE PLPGSQL;


--#4 newWorker
CREATE OR REPLACE FUNCTION arbordb.newWorker(SSN int, first varchar(30), last varchar(30), mid char(1), rank RANK_DOM, state varchar(2))
RETURNS void AS $$
BEGIN
    INSERT INTO arbordb.WORKER VALUES(SSN, first, last, mid, rank);
    INSERT INTO arbordb.EMPLOYED VALUES(state, SSN);
    RETURN;
END;
$$ LANGUAGE PLPGSQL;


--#5 employWorkerToState
CREATE OR REPLACE FUNCTION arbordb.employWorkerToState(state varchar(2), SSN int)
RETURNS void AS $$
BEGIN
    INSERT INTO arbordb.EMPLOYED VALUES(state, SSN);
    RETURN;
END;
$$ LANGUAGE PLPGSQL;


--#6 placeSensor
CREATE OR REPLACE FUNCTION arbordb.placeSensor(energy int, X real, Y real, maintainer_id int)
RETURNS INTEGER AS
$$
DECLARE
    cur_time timestamp;
    new_id integer;
BEGIN

    RAISE NOTICE 'placeSensor function called with energy=%, X=%, Y=%, maintainer_id=%', energy, X, Y, maintainer_id;

    SELECT MAX(synthetic_time) INTO cur_time FROM arbordb.CLOCK;
    SELECT MAX(sensor_id)+1 INTO new_id FROM arbordb.SENSOR;
    IF new_id IS NULL THEN
        new_id = 1;
    end if;

    INSERT INTO arbordb.SENSOR VALUES(new_id, cur_time, energy, cur_time, X, Y, maintainer_id);
    RETURN new_id;
    end;
$$LANGUAGE plpgsql;

--#7 generate Report
CREATE OR REPLACE FUNCTION arbordb.generateReport(sensor_id integer, report_time timestamp, temperature real)
RETURNS void AS
$$
BEGIN
    INSERT INTO arbordb.REPORT VALUES(sensor_id, report_time, temperature);
end;
$$LANGUAGE plpgsql;


--#8 removeSpeciesFromForest
CREATE OR REPLACE FUNCTION arbordb.removeSpeciesFromForest(genusToRemove varchar(30), epithetToRemove varchar(30), forest_noToRemove int)
RETURNS void AS
$$
BEGIN
    DELETE FROM arbordb.FOUND_IN
        WHERE arbordb.FOUND_IN.genus = genusToRemove
          AND arbordb.FOUND_IN.epithet = epithetToRemove
          AND arbordb.FOUND_IN.forest_no = forest_noToRemove;
end;
$$LANGUAGE plpgsql;


--#9 deleteWorker
CREATE OR REPLACE FUNCTION arbordb.deleteWorker(int)
RETURNS void AS
$$
BEGIN
    DELETE FROM arbordb.SENSOR
        WHERE  maintainer_id = $1;      --all sensors maintained by this worker are removed
    DELETE FROM arbordb.EMPLOYED
        WHERE worker = $1;              --all states that employ this worker no longer will
    DELETE FROM arbordb.WORKER
        WHERE ssn = $1;                 --worker is removed from worker relation
end;
$$LANGUAGE plpgsql;


--#10 moveSensor
CREATE OR REPLACE FUNCTION  arbordb.moveSensor(sensorToMove int, newX real, newY real)
RETURNS void AS
$$
BEGIN
    UPDATE arbordb.SENSOR
    SET X = newX, Y = newY
    WHERE sensor_id = sensorToMove;
end;
$$LANGUAGE plpgsql;


--#11 removeWorkerFromState
CREATE OR REPLACE FUNCTION arbordb.removeWorkerFromState(workerSsn int, abbreviation char(2))
RETURNS VOID AS $$
DECLARE
    reassign int;
BEGIN
    SELECT MIN(worker)
    INTO reassign
    FROM arbordb.EMPLOYED
    WHERE state = abbreviation and worker != workerSsn;

    IF reassign IS NOT NULL THEN
        --there is another worker in the state so reassign
        UPDATE arbordb.SENSOR
        SET maintainer_id = reassign
        WHERE maintainer_id = workerSsn;
    ELSE
        --not another worker to reassign to so just delete all sensors that were attached to the worker
        DELETE FROM arbordb.SENSOR
        WHERE maintainer_id = workerSsn;
    end if;

    DELETE FROM arbordb.EMPLOYED
    WHERE state = abbreviation AND worker = workerSsn;
end;
$$ LANGUAGE plpgsql;


--#12 removeSensor
--Given a sensor id, remove the sensor by deleting the sensor from the sensor relation. In addition, any reports generated by the sensor should be removed
CREATE OR REPLACE FUNCTION arbordb.removeSensor(sensorId int)
RETURNS VOID AS $$
BEGIN
    DELETE FROM arbordb.REPORT WHERE sensor_id = sensorId;
    DELETE FROM arbordb.SENSOR WHERE sensor_id = sensorId;
end;
$$ LANGUAGE plpgsql;


--#13 listSensors
--Given a forest id, display all sensors within the specified forest
--maybe forest -> state -> worker -> sensor
--or maybe where forest.MBR_XMin < sensor.x < forest.MBR_XMax     and same for y
--mbr is minimum bounding rectangle?
CREATE OR REPLACE FUNCTION arbordb.listSensors(forestId int)
RETURNS TABLE (
    sensor_id       int,
    last_charged    timestamp,
    energy          int,
    last_read       timestamp,
    X               real,
    Y               real,
    maintainer_id   int
) AS $$
BEGIN
    RETURN QUERY
    SELECT s.*
    FROM arbordb.SENSOR s
    JOIN arbordb.FOREST f ON s.X > f.MBR_XMin AND s.X < f.MBR_XMax AND s.Y > f.MBR_YMin AND s.Y < f.MBR_YMax
    WHERE f.forest_no = forestId;
end;
$$LANGUAGE plpgsql;

--#14 listMaintainedSensors
--Given a worker’s SSN, display all sensors that the worker is currently maintaining
CREATE OR REPLACE FUNCTION arbordb.listMaintainedSensors(workerSSN int)
RETURNS TABLE (
    sensor_id       int,
    last_charged    timestamp,
    energy          int,
    last_read       timestamp,
    X               real,
    Y               real,
    maintainer_id   int
) AS $$
BEGIN
    RETURN QUERY
    SELECT s.*
    FROM arbordb.SENSOR s
    JOIN arbordb.WORKER w ON s.maintainer_id = w.ssn
    WHERE w.ssn = workerSSN;
end;
$$LANGUAGE plpgsql;

--#15 locateTreeSpecies
--Find all forests that contain any tree species whose genus matches the pattern a or epithet matches the pattern b
CREATE OR REPLACE FUNCTION arbordb.locateTreeSpecies(a varchar, b varchar)
RETURNS TABLE (
    forest_no       int,
    name            varchar(30),
    area            int,
    acid_level      real,
    MBR_XMin        real,
    MBR_XMax        real,
    MBR_YMin        real,
    MBR_YMax        real
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT f.*
    FROM arbordb.FOREST f
    JOIN arbordb.FOUND_IN fi on f.forest_no = fi.forest_no
    Where fi.genus = a or fi.epithet = b;
end;
$$ LANGUAGE plpgsql;


-- PHASE 2 Part 2 --

--#1 rankForestSensors
--  rank all forests by number of sensors
DROP FUNCTION IF EXISTS arbordb.rankforestsensors();
CREATE OR REPLACE FUNCTION arbordb.rankForestSensors()
RETURNS TABLE (
    forest_name varchar(30),
    sensors     int
) AS $$
DECLARE
    f record;
    num_sensors int;
BEGIN
    DROP TABLE IF EXISTS result;
    CREATE TEMPORARY TABLE result(forest_name varchar(30), sensors int) ON COMMIT DROP;

    FOR f IN SELECT * FROM arbordb.FOREST LOOP -- loop through each forest and select sensors inside of forest coordinates
        SELECT COUNT(*)
        INTO num_sensors
        FROM arbordb.SENSOR
        WHERE X <= f.MBR_Xmax AND X >= f.MBR_YMin AND Y <= f.MBR_YMax AND Y >= f.MBR_YMin;

        INSERT INTO result VALUES(f.name, num_sensors); -- insert forest name and number of sensors found in forest into result table
    END LOOP;

    RETURN QUERY SELECT * FROM result ORDER BY sensors DESC;
END
$$ LANGUAGE plpgsql;

--#2 habitableEnvironment
--  given genus, epithet, and k years,
--  let S= ideal_temp
--  return forests where S-5 <= avg temp over k years <= S+5

CREATE OR REPLACE function arbordb.habitableEnvironment(genus_param varchar(30), epithet_param varchar(30), k int)
RETURNS TABLE (
    forest_no   int,
    name        varchar(30),
    area        int,
    acid_level  real,
    MBR_XMin    real,
    MBR_XMax    real,
    MBR_YMin    real,
    MBR_YMax    real
    ) AS
    $$
    DECLARE min_temp    int;
    DECLARE max_temp    int;
    DECLARE goal_temp   int;
    DECLARE AVG_temp    int;
    DECLARE sum         int;
    DECLARE count       int;
    DECLARE f           record;
    BEGIN
        sum := 0;
        --declare temp table habitable
        DROP TABLE IF EXISTS habitable;
        CREATE TEMPORARY TABLE habitable(forest_no int, name varchar(30), area int, acid_level real, MBR_XMin real, MBR_XMax real, MBR_YMin real, MBR_YMax real);

        --select ideal_temp from tree_species where genus and epithet match input into goal_temp
        SELECT ideal_temperature FROM arbordb.TREE_SPECIES WHERE genus = genus_param AND epithet = epithet_param
        INTO goal_temp;

        --calculate max and min temp
        min_temp := goal_temp - 5;
        max_temp := goal_temp + 5;

        --join report and sensor on sensor_id so we have a table with all report fields and sensor location for each report
        CREATE OR REPLACE VIEW report_locations AS
            SELECT arbordb.REPORT.*, arbordb.SENSOR.X, arbordb.SENSOR.Y
            FROM arbordb.REPORT JOIN arbordb.SENSOR ON REPORT.sensor_id = SENSOR.sensor_id;

        -- for each forest, select temperature values from report_locations where sensor location is within forest,
        -- get the sum and count of relevant temperature values for each forest
        FOR f in SELECT * FROM arbordb.FOREST LOOP

            -- select sum and count of temperature,  from divide sum by count, place into avg_temp
            SELECT SUM(temperature) INTO sum FROM report_locations
                WHERE X < f.MBR_XMax AND X > f.MBR_XMin
                        AND Y < f.MBR_YMax AND Y > f.MBR_YMin -- check report was from inside forest
                        AND report_time >= current_date - interval '1 year' * y; -- check report was dated within y years of current date
            SELECT COUNT(*) INTO count FROM report_locations
                WHERE X < f.MBR_XMax AND X > f.MBR_XMin
                        AND Y < f.MBR_YMax AND Y > f.MBR_YMin
                        AND report_time >= current_date - interval '1 year' * y;
            AVG_temp := (sum / count);

            -- if avg temp <max_temp && >min_temp, insert current forest row into habitable
            IF AVG_temp < max_temp AND AVG_temp > min_temp THEN
                INSERT INTO HABITABLE VALUES(f.forest_no, f.name, f.area, f.acid_level, f.MBR_XMin, f.MBR_XMax, f.MBR_YMin, f.MBR_YMax);
            END IF;
        END LOOP;

        -- return habitable
        RETURN QUERY SELECT * FROM habitable;
    END $$ LANGUAGE plpgsql;

--#3 topSensors
-- given k and x, return top k sensors
-- ranked by number of reports generated
-- in the last x months

CREATE OR REPLACE FUNCTION arbordb.topSensors(k INT, x INT)
RETURNS TABLE
    (
        sensor_id    int,
        total_reports bigint
    )AS
$$
DECLARE end_date timestamp;
BEGIN
    end_date := (SELECT synthetic_time - (interval '30 days' * x)
                 FROM arbordb.CLOCK);                   --calculate the date to stop looking at
    RETURN QUERY
    SELECT report.sensor_id, COUNT(*) AS total_reports -- count the number of reports created by each sensor
    FROM arbordb.REPORT
    WHERE report_time >= end_date
    GROUP BY report.sensor_id
    ORDER BY total_reports DESC                 -- descending highest to lowest
    LIMIT k;                                    -- limit the results returned to only the top k
end;
$$ LANGUAGE plpgsql;

--#4 threeDegrees
-- given two forest_no, return a pat between them with <= 3 hops.
-- hops are defined as a connection between forests where each
-- forest has the same tree species.
-- output a string formatted as "[F1]->[F2]->[F3],
-- where Fn is a forest_no
CREATE OR REPLACE FUNCTION arbordb.threeDegrees(f1 INT, f2 INT)
RETURNS VARCHAR AS $$
DECLARE
    species RECORD;
    connecting_forests RECORD;
    species2 RECORD;
    connecting_forests2 RECORD;
    species3 RECORD;
    connecting_forests3 RECORD;
BEGIN
    --Checking for 1 hop
    FOR species IN (SELECT DISTINCT genus, epithet FROM arbordb.FOUND_IN WHERE forest_no = f1) LOOP
        --For each tree species, get a list of forests that contain that species
        FOR connecting_forests IN (SELECT DISTINCT f.forest_no
                                    FROM arbordb.FOUND_IN f
                                    WHERE (f.genus, f.epithet) = (species.genus, species.epithet)
                                    AND f.forest_no != f1) LOOP
            --Check if any of the connecting forests are f2 and return if so
            --RAISE NOTICE 'number: %', connecting_forests.forest_no;
            IF connecting_forests.forest_no = f2 THEN
                RETURN f1 || ' -> ' || f2;
            END IF;

        end loop;
    end loop;

    --Next step is checking for 2 hops
    FOR species IN (SELECT DISTINCT genus, epithet FROM arbordb.FOUND_IN WHERE forest_no = f1) LOOP
        --Again for each tree species, get a list of forests that contain that species
        FOR connecting_forests IN (SELECT DISTINCT f.forest_no
                                    FROM arbordb.FOUND_IN f
                                    WHERE (f.genus, f.epithet) = (species.genus, species.epithet)
                                    AND f.forest_no != f1) LOOP
            --Again for the next hop
            FOR species2 IN (SELECT DISTINCT genus, epithet FROM arbordb.FOUND_IN WHERE forest_no = connecting_forests.forest_no) LOOP
                FOR connecting_forests2 IN (SELECT DISTINCT f2.forest_no
                                    FROM arbordb.FOUND_IN f2
                                    WHERE (f2.genus, f2.epithet) = (species2.genus, species2.epithet)
                                    AND f2.forest_no != connecting_forests.forest_no) LOOP

                    --RAISE NOTICE 'number: %', connecting_forests2.forest_no;
                    IF connecting_forests2.forest_no = f2 THEN
                        RETURN f1 || ' -> ' || connecting_forests.forest_no || ' -> ' || f2;
                    END IF;

                end loop;
            end loop;

        end loop;
    end loop;


    --Last step is for 3 hops
    FOR species IN (SELECT DISTINCT genus, epithet FROM arbordb.FOUND_IN WHERE forest_no = f1) LOOP
        FOR connecting_forests IN (SELECT DISTINCT f.forest_no
                                    FROM arbordb.FOUND_IN f
                                    WHERE (f.genus, f.epithet) = (species.genus, species.epithet)
                                    AND f.forest_no != f1) LOOP
            FOR species2 IN (SELECT DISTINCT genus, epithet FROM arbordb.FOUND_IN WHERE forest_no = connecting_forests.forest_no) LOOP
                FOR connecting_forests2 IN (SELECT DISTINCT f2.forest_no
                                   FROM arbordb.FOUND_IN f2
                                   WHERE (f2.genus, f2.epithet) = (species2.genus, species2.epithet)
                                     AND f2.forest_no != connecting_forests.forest_no) LOOP
                    --Now with a third loop for the third hop
                    FOR species3 IN (SELECT DISTINCT genus, epithet FROM arbordb.FOUND_IN WHERE forest_no = connecting_forests2.forest_no) LOOP
                        FOR connecting_forests3 IN (SELECT DISTINCT f3.forest_no
                                   FROM arbordb.FOUND_IN f3
                                   WHERE (f3.genus, f3.epithet) = (species3.genus, species3.epithet)
                                     AND f3.forest_no != connecting_forests2.forest_no) LOOP

                            --Checking if the third hop connects to f2
                            --RAISE NOTICE 'number: %', connecting_forests3.forest_no;
                            IF connecting_forests3.forest_no = f2 THEN
                                RETURN f1 || ' -> ' || connecting_forests.forest_no || ' -> ' || connecting_forests2.forest_no || ' -> ' || f2;
                            END IF;

                        end loop;
                    end loop;

                end loop;
            end loop;

        end loop;
    end loop;

    --If made it to this point then no path was found
    RETURN 'No path found';
end;
$$ LANGUAGE plpgsql;

