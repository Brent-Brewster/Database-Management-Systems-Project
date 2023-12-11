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
