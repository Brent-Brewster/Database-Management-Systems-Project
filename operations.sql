-- PHASE 2 Part 2 --

--#1 rankForestSensors
--  rank all forests by number of sensors
DROP FUNCTION IF EXISTS rankforestsensors();
CREATE OR REPLACE FUNCTION rankForestSensors()
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
        FROM SENSOR
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

CREATE OR REPLACE function habitableEnvironment(genus_param varchar(30), epithet_param varchar(30), k int)
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
            SELECT REPORT.*, SENSOR.X, SENSOR.Y
            FROM arbordb.REPORT JOIN arbordb.SENSOR ON REPORT.sensor_id = SENSOR.sensor_id;

        -- for each forest, select temperature values from report_locations where sensor location is within forest,
        -- get the sum and count of relevant temperature values for each forest
        FOR f in SELECT * FROM FOREST LOOP

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

CREATE OR REPLACE FUNCTION topSensors(k INT, x INT)
RETURNS TABLE
        (
            sensor_id    int,
            total_reports int
        )AS
$$
DECLARE end_date timestamp;
BEGIN
    end_date := (SELECT synthetic_time - (interval '30 days' * x)
                 FROM CLOCK);                   --calculate the date to stop looking at
    RETURN QUERY
    SELECT sensor_id, COUNT(*) AS total_reports -- count the number of reports created by each sensor
    FROM REPORT
    WHERE report_time >= end_date
    GROUP BY sensor_id
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
CREATE OR REPLACE FUNCTION threeDegrees(f1 INT, f2 INT)
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
    FOR species IN (SELECT DISTINCT genus, epithet FROM FOUND_IN WHERE forest_no = f1) LOOP
        --For each tree species, get a list of forests that contain that species
        FOR connecting_forests IN (SELECT DISTINCT f.forest_no
                                    FROM FOUND_IN f
                                    WHERE (f.genus, f.epithet) = (species.genus, species.epithet)
                                    AND f.forest_no != f1) LOOP
            --Check if any of the connecting forests are f2 and return if so
            --RAISE NOTICE 'number: %', connecting_forests.forest_no;
            IF connecting_forests.forest_no = f2 THEN
                RETURN f1 || ' → ' || f2;
            END IF;

        end loop;
    end loop;

    --Next step is checking for 2 hops
    FOR species IN (SELECT DISTINCT genus, epithet FROM FOUND_IN WHERE forest_no = f1) LOOP
        --Again for each tree species, get a list of forests that contain that species
        FOR connecting_forests IN (SELECT DISTINCT f.forest_no
                                    FROM FOUND_IN f
                                    WHERE (f.genus, f.epithet) = (species.genus, species.epithet)
                                    AND f.forest_no != f1) LOOP
            --Again for the next hop
            FOR species2 IN (SELECT DISTINCT genus, epithet FROM FOUND_IN WHERE forest_no = connecting_forests.forest_no) LOOP
                FOR connecting_forests2 IN (SELECT DISTINCT f2.forest_no
                                    FROM FOUND_IN f2
                                    WHERE (f2.genus, f2.epithet) = (species2.genus, species2.epithet)
                                    AND f2.forest_no != connecting_forests.forest_no) LOOP

                    --RAISE NOTICE 'number: %', connecting_forests2.forest_no;
                    IF connecting_forests2.forest_no = f2 THEN
                        RETURN f1 || ' → ' || connecting_forests.forest_no || ' → ' || f2;
                    END IF;

                end loop;
            end loop;

        end loop;
    end loop;


    --Last step is for 3 hops
    FOR species IN (SELECT DISTINCT genus, epithet FROM FOUND_IN WHERE forest_no = f1) LOOP
        FOR connecting_forests IN (SELECT DISTINCT f.forest_no
                                    FROM FOUND_IN f
                                    WHERE (f.genus, f.epithet) = (species.genus, species.epithet)
                                    AND f.forest_no != f1) LOOP
            FOR species2 IN (SELECT DISTINCT genus, epithet FROM FOUND_IN WHERE forest_no = connecting_forests.forest_no) LOOP
                FOR connecting_forests2 IN (SELECT DISTINCT f2.forest_no
                                   FROM FOUND_IN f2
                                   WHERE (f2.genus, f2.epithet) = (species2.genus, species2.epithet)
                                     AND f2.forest_no != connecting_forests.forest_no) LOOP
                    --Now with a third loop for the third hop
                    FOR species3 IN (SELECT DISTINCT genus, epithet FROM FOUND_IN WHERE forest_no = connecting_forests2.forest_no) LOOP
                        FOR connecting_forests3 IN (SELECT DISTINCT f3.forest_no
                                   FROM FOUND_IN f3
                                   WHERE (f3.genus, f3.epithet) = (species3.genus, species3.epithet)
                                     AND f3.forest_no != connecting_forests2.forest_no) LOOP

                            --Checking if the third hop connects to f2
                            --RAISE NOTICE 'number: %', connecting_forests3.forest_no;
                            IF connecting_forests3.forest_no = f2 THEN
                                RETURN f1 || ' → ' || connecting_forests.forest_no || ' → ' || connecting_forests2.forest_no || ' → ' || f2;
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
