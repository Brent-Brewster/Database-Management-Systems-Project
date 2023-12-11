//Compile with javac -cp "postgresql-42.6.0.jar;." ArborDB.java
//Run with java -cp "postgresql-42.6.0.jar;." ArborDB
import java.sql.*;
import java.util.NoSuchElementException;
import java.util.Properties;
import java.util.Scanner;

public class ArborDB{

    public String getUserInputString(String request, Scanner scanner) {
        try {
            System.out.println(request);
            return scanner.nextLine();
        } catch (NoSuchElementException e) {
            System.out.println("No input detected.");
            return null;
        } catch (IllegalArgumentException e) {
            System.out.println("Scanner was likely closed before reading the user input.");
            return null;
        } 
    }
    
    public String getUserInputChar(String request, Scanner scanner) {
        String userString = getUserInputString(request, scanner);
        while(userString.length() > 1)
        {
            userString = getUserInputString(request, scanner);
        }
        return userString;
    }

    public String getUserInputRank(String request, Scanner scanner) {
        String rank = getUserInputString(request,scanner);
        if(rank.equals("Lead") || rank.equals("Senior") || rank.equals("Associate")) {
            return rank;
        }
        else return getUserInputRank(request, scanner);
    }

    public String getUserInputState(String request, Scanner scanner) {
        String state = getUserInputString(request, scanner);
        if(state.length() > 2) {
            return getUserInputState(request, scanner);
        }
        else return state;
    }

    private int getUserInputInt(String request, Scanner scanner) {
        String userString = getUserInputString(request, scanner);
        try {
             return Integer.valueOf(userString);
        } catch (NumberFormatException err) {
            System.out.println("Invalid Number Recived");
            return getUserInputInt(request, scanner);
        }
    }

    public float getUserInputFloat(String request, Scanner scan) {
        String userString = getUserInputString(request, scan);
        try {
            return Float.parseFloat(userString);
        } catch (NumberFormatException err) {
            return getUserInputFloat(request, scan);
        }
    }

    public String getRaunkiaerLifeForm(String request, Scanner scan) {
        String userString = getUserInputString(request, scan);
        if(userString.equals("Phanerophytes") || userString.equals("Epiphytes") || userString.equals("Chamaephytes") || userString.equals("Hemicryptophytes") || userString.equals("Cryptophytes") || userString.equals("Therophytes") || userString.equals("Aerophytes")) {
            return userString;
        }
        else return getRaunkiaerLifeForm(request, scan);
    }

    //#1 
    public Connection connect(String url,Properties props, Scanner scan) {
        ConnectionConfig config = new ConnectionConfig(scan);
        props.setProperty("user", config.getUser());
        props.setProperty("password", config.getPass());
        try {
        Connection conn = DriverManager.getConnection(url, props);
        return conn;
        } catch(SQLException err) {
            System.out.println("Connection Failed Attempting To Connect Again:");
            return connect(url, props, scan);
        }
    }
    //#5
    public void newWorker(Connection conn, Scanner scanner) {
        try {
            CallableStatement newWorker = conn.prepareCall("{ ? = call arbordb.newWorker( ?, ?, ?, ?, ?, ? ) }");
            newWorker.registerOutParameter(1, Types.OTHER);
            newWorker.setInt(2, Integer.valueOf(getUserInputString("Enter the SSN of the Worker you'd like to add: ", scanner)));
            String[] name = getUserInputString("Enter the first and last name seperated by a space: ", scanner).split(" ", 2);
            newWorker.setString(3, name[0]);
            newWorker.setString(4, name[1]);
            newWorker.setString(5, getUserInputChar("Enter the middle inital of the worker: ", scanner));
            newWorker.setString(6, getUserInputRank("Enter the Rank of the worker: ", scanner));
            newWorker.setString(7, getUserInputState("Enter the State abbreviation: ", scanner));
            newWorker.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }
    //#10
    public void deleteWorker(Connection conn, Scanner scan) {
        try {
            CallableStatement deleteWorker = conn.prepareCall("{ ? = call arbordb.deleteWorker( ? ) }");
            deleteWorker.registerOutParameter(1, Types.OTHER);
            deleteWorker.setInt(2, getUserInputInt("Enter the SSN of the worker you'd like to delete: ", scan));
            deleteWorker.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#7
    public void placeSensor(Connection conn, Scanner scan) {
        try {
            CallableStatement placeSensor = conn.prepareCall("{ ? = call arbordb.placeSensor( ?, ?, ?, ? ) }");
            placeSensor.registerOutParameter(1, Types.INTEGER);
            placeSensor.setInt(2, getUserInputInt("Enter the energy level of the sensor: ", scan));
            placeSensor.setFloat(3, getUserInputFloat("Enter the X value of the sensor: ", scan));
            placeSensor.setFloat(4, getUserInputFloat("Enter the Y value of the sensor: ", scan));
            placeSensor.setInt(5, getUserInputInt("Enter the maintainer's SSN: ", scan));
            placeSensor.execute();
            int returnValue = placeSensor.getInt(1);
            System.out.println("Generated ID: " + returnValue);
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#11
    public void moveSensor(Connection conn, Scanner scan) {
        try {
            Statement stmt = conn.createStatement();
            String countQuery = "SELECT COUNT(sensor_id) No_of_sensors FROM arbordb.SENSOR; ";
            ResultSet result = stmt.executeQuery(countQuery);
            result.next();
            if(result.getInt(1) < 1) {
                System.out.println("\nNo Sensors To Redeploy\n");
                return;
            }
            CallableStatement moveSensor = conn.prepareCall("{ ? = call arbordb.moveSensor( ?, ?, ? ) }");
            moveSensor.registerOutParameter(1, Types.OTHER);
            moveSensor.setInt(2, getUserInputInt("Enter the ID of the sensor you'd like to move: ", scan));
            moveSensor.setFloat(3, getUserInputFloat("Enter the new X value: ", scan));
            moveSensor.setFloat(4, getUserInputFloat("Enter the new Y value: ", scan));
            moveSensor.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#6
    public void employWorkerToState(Connection conn, Scanner scan) {
        try {
            CallableStatement employWorkerToState = conn.prepareCall("{ ? = call arbordb.EmployWorkerToState( ?, ? ) }");
            employWorkerToState.registerOutParameter(1, Types.OTHER);
            employWorkerToState.setString(2, getUserInputState("Enter the state abbreviation you'd like to employ the worker to: ", scan));
            employWorkerToState.setInt(3, getUserInputInt("Enter the SSN of the user you'd like that state to employ: ", scan));
            employWorkerToState.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#19
    public void topSensors(Connection conn, Scanner scan) {
        try {
            CallableStatement topSensors = conn.prepareCall("SELECT * FROM arbordb.topSensors(?, ?)");
            topSensors.setInt(1, getUserInputInt("Enter the number of sensors you would like to see: ", scan));
            topSensors.setInt(2, getUserInputInt("Enter the number of months you would like to consider: ", scan));
            ResultSet rs = topSensors.executeQuery();
    
            if (rs != null) {
                System.out.println("Sensor ID | Total Reports");
                System.out.println("-------------------------");
                while (rs.next()) {
                    System.out.println(rs.getInt(1) + "     | " + rs.getInt(2));
                }
                rs.close();
            } else {
                System.out.println("No result obtained.");
            }
            topSensors.close();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while (err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }    
 
    //#16
    public void locateTreeSpecies(Connection conn,  Scanner scan) {
        try {
            Statement locateTreeSpecies = conn.createStatement();
           
            String genusInput = getUserInputString("Enter the genus pattern: ", scan);
            String epithetInput = getUserInputString("Enter the epithet pattern: ", scan);
            String queryString = "SELECT * FROM arbordb.LocateTreeSpecies('"+genusInput+"', '"+epithetInput+"')";

            locateTreeSpecies.executeQuery(queryString);

            ResultSet result = locateTreeSpecies.getResultSet();
            System.out.println("Forest_no   name    area     acid_level  mbr_xmin  mbr_xmax  mbr_ymin  mbr_ymax");
            System.out.println("---------------------------------------------------------------------------------");

            while(result.next()){
                int forestNo = result.getInt("forest_no");
                String name = result.getString("name");
                int area = result.getInt("area");
                int acidLevel = result.getInt("acid_level");
                int xMin = result.getInt("mbr_xmin");
                int xMax = result.getInt("mbr_xmax");
                int yMin = result.getInt("mbr_ymin");
                int yMax = result.getInt("mbr_ymax");

                System.out.println(forestNo+"     |  "+name+"  |   "+area+"   |   "+acidLevel+"   |   "+xMin+"   |   "+xMax+"   |   "+yMin+"   |   "+yMax);
            }
            System.out.println("\n");
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }
    //#2
    public void addForest(Connection conn, Scanner scan) {
        try {
            CallableStatement addForest = conn.prepareCall("{ ? = call arbordb.addForest( ?, ?, ?, ?, ?, ?, ? ) }");
            addForest.registerOutParameter(1, Types.OTHER);
            addForest.setString(2, getUserInputString("Enter the name of the forest you'd like to add: ", scan));
    
            addForest.setInt(3, getUserInputInt("Enter the area of the forest: ", scan));
            addForest.setFloat(4, getUserInputFloat("Enter the acid level of the forest: ", scan));
            addForest.setFloat(5, getUserInputFloat("Enter the MBR_XMin of the forest: ", scan));
            addForest.setFloat(6, getUserInputFloat("Enter the MBR_XMax of the forest: ", scan));
            addForest.setFloat(7, getUserInputFloat("Enter the MBR_YMin of the forest: ", scan));
            addForest.setFloat(8, getUserInputFloat("Enter the MBR_YMax of the forest: ", scan));

            addForest.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#3
    public void addTreeSpecies(Connection conn, Scanner scan) {
        try {
            CallableStatement addTreeSpecies = conn.prepareCall("{ ? = call arbordb.addTreeSpecies( ?, ?, ?, ?, ?) }");
            addTreeSpecies.registerOutParameter(1, Types.OTHER);
            addTreeSpecies.setString(2, getUserInputString("Enter the genus of the species: ", scan));
            addTreeSpecies.setString(3, getUserInputString("Enter the epithet of the species: ", scan));
            addTreeSpecies.setFloat(4, getUserInputFloat("Enter the ideal temperature of the species: ", scan));
            addTreeSpecies.setFloat(5, getUserInputFloat("Enter the largest height of the species: ", scan));
            addTreeSpecies.setString(6, getRaunkiaerLifeForm("Enter the raunkiaer life form of the species: ", scan));

            addTreeSpecies.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#4
    public void addSpeciesToForest(Connection conn, Scanner scan){
        try {
            CallableStatement AddSpeciesToForest = conn.prepareCall("{ ? = call arbordb.AddSpeciesToForest( ?, ?, ?) }");
            AddSpeciesToForest.registerOutParameter(1, Types.OTHER);
            AddSpeciesToForest.setInt(2, getUserInputInt("Enter the forest number: ", scan));
            AddSpeciesToForest.setString(3, getUserInputString("Enter the genus of the species: ", scan));
            AddSpeciesToForest.setString(4, getUserInputString("Enter the epithet of the species: ", scan));

            AddSpeciesToForest.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#8 
    public void employeWorkerToState(Connection conn, Scanner scan){
        try {
            CallableStatement employWorkerToState = conn.prepareCall("{ ? = call arbordb.employWorkerToState( ?, ?) }");
            employWorkerToState.registerOutParameter(1, Types.OTHER);
            employWorkerToState.setInt(2, getUserInputInt("Enter the state abbreviation: ", scan));
            employWorkerToState.setString(3, getUserInputString("Enter the worker SSN: ", scan));

            employWorkerToState.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#9
    public void removeSpeciesfromForest(Connection conn, Scanner scan){
        try {
            CallableStatement removeSpeciesfromForest = conn.prepareCall("{ ? = call arbordb.removeSpeciesfromForest( ?, ?, ?) }");
            removeSpeciesfromForest.registerOutParameter(1, Types.OTHER);
            removeSpeciesfromForest.setString(2, getUserInputString("Enter the species genus: ", scan));
            removeSpeciesfromForest.setString(3, getUserInputString("Enter the species epithet: ", scan));
            removeSpeciesfromForest.setInt(4, getUserInputInt("Enter the forest number: ", scan));

            removeSpeciesfromForest.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#12 
    public void removeWorkerFromState(Connection conn, Scanner scan){
        try {
            CallableStatement removeWorkerFromState = conn.prepareCall("{ ? = call arbordb.removeWorkerFromState( ?, ?) }");
            removeWorkerFromState.registerOutParameter(1, Types.OTHER);
            removeWorkerFromState.setInt(2, getUserInputInt("Enter the worker's SSN: ", scan));
            removeWorkerFromState.setString(3, getUserInputString("Enter the state abbreviation: ", scan));

            removeWorkerFromState.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#13
    public void removeSensor(Connection conn, Scanner scan){
        try {
            CallableStatement removeSensor = conn.prepareCall("{ ? = call arbordb.removeSensor(?) }");
            removeSensor.registerOutParameter(1, Types.OTHER);

            String allSensorsRequest = "";
            String confirmationRequest = "";

            while(!(allSensorsRequest.equals("All") || allSensorsRequest.equals("Selected"))){

                allSensorsRequest = getUserInputString("Would you like to remove all sensors or selected sensors? Enter 'All' or 'Selected'", scan);

                if (allSensorsRequest.equals("All")){
                    while(!(confirmationRequest.equals("Yes") || allSensorsRequest.equals("No"))){
                        confirmationRequest = getUserInputString("Are you sure you want to remove all sensors? Enter 'Yes' or 'No'", scan);
                        if(confirmationRequest.equals("Yes")){
                           
                            Statement deleteAll = conn.createStatement();
                            String query = "DELETE FROM arbordb.SENSOR";
                            deleteAll.executeUpdate(query);
                            
                            System.out.println("All Sensors (and reports) Deleted");
                            return;
                        }
                        else if (confirmationRequest.equals("No")){

                            System.out.println("No Sensors were Removed");
                            return;
                        }
                    }
                }
                else if (allSensorsRequest.equals("Selected")){
                    //setup a query to select all sensors
                    Statement statement = conn.createStatement();
                    String query = "SELECT * FROM arbordb.SENSOR";
                    ResultSet result = statement.executeQuery(query);
                   
                    int sensorIdInput;

                    //go through sensors one by one
                    while(result.next()){
                        //collect sensor data from query
                        int sensorId = result.getInt("sensor_id");
                        java.sql.Timestamp last_charged = result.getTimestamp("last_charged");
                        int energy = result.getInt("energy");
                        java.sql.Timestamp last_read = result.getTimestamp("last_read");
                        int x = result.getInt("X");
                        int y = result.getInt("Y");
                        int maintainer_id = result.getInt("maintainer_id");

                        System.out.println("Id:"+sensorId +",  last charged: "+ last_charged+",  energy level: "+energy+",  last read: "+last_read+",  X: "+x+",  Y: "+y+",  maintainer id: "+maintainer_id);
                        
                        sensorIdInput = getUserInputInt("If you want to remove this sensor, input its sensor ID\nOtherwise, enter 0 to see the next sensor, or 1 to return to main menu", scan);
                        if(sensorIdInput == sensorId){
                            removeSensor.setInt(2, sensorId);
                            removeSensor.execute();
                        }
                        else if(sensorIdInput == 0){
                            continue;
                        }
                        else if(sensorIdInput == -1){
                            return;
                        }
                        else{
                            System.out.println("Please enter the corresponding sensor ID, 0, or -1");
                        }
                    }
                    
                    removeSensor.setInt(2, getUserInputInt("Enter the sensor ID: ", scan));

                    removeSensor.execute();
                    result.close();
                }
            }
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }

    //#14
    public void listSensors(Connection conn, Scanner scan){
        try {
            Statement listSensors = conn.createStatement();
            int forestNoParam = getUserInputInt("Enter the forest number you'd like to search in", scan);
            String query = "SELECT * FROM arbordb.listSensors("+forestNoParam+")";
            listSensors.executeQuery(query);
            
            ResultSet result = listSensors.getResultSet();

            System.out.println("sensor_id   last_charged   energy       last_read   x   y   maintainer_id");
            System.out.println("---------------------------------------------------------------------------------------------");
            while(result.next()){
                int sensor_id = result.getInt("sensor_id");
                java.sql.Timestamp last_charged = result.getTimestamp("last_charged");
                int energy = result.getInt("energy");
                java.sql.Timestamp last_read = result.getTimestamp("last_read");
                int x = result.getInt("x");
                int y = result.getInt("y");
                int maintainer_id = result.getInt("maintainer_id");

                System.out.println(sensor_id + " | " + last_charged + " | " + energy+ " | " +last_read+ " | " +x+ " | " +y+ " | " +maintainer_id );
            }
            System.out.println("\n\n");
            result.close();

        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        }
    }


    //#15
    public void listMaintainedSensors(Connection conn, Scanner scan) {
        try {
            Statement listMaintainedSensors = conn.createStatement();
            int workerSsnParam = getUserInputInt("Enter the worker's ssn who you'd like to search: ", scan);
            String query = "SELECT * FROM arbordb.listMaintainedSensors("+workerSsnParam+")";
            listMaintainedSensors.executeQuery(query);
            
            ResultSet result = listMaintainedSensors.getResultSet();

            if (result == null){
                System.out.println("There are no sensors in that forest");
            }

            System.out.println("sensor_id   last_charged   energy         last_read   x   y   maintainer_id");
            System.out.println("---------------------------------------------------------------------------------------------");
            while(result.next()){
                int sensor_id = result.getInt("sensor_id");
                java.sql.Timestamp last_charged = result.getTimestamp("last_charged");
                int energy = result.getInt("energy");
                java.sql.Timestamp last_read = result.getTimestamp("last_read");
                int x = result.getInt("x");
                int y = result.getInt("y");
                int maintainer_id = result.getInt("maintainer_id");

                System.out.println(sensor_id + " | " + last_charged + " | " + energy+ " | " +last_read+ " | " +x+ " | " +y+ " | " +maintainer_id );
            }
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        } 
    }

    //#8
    public void generateReport(Connection conn, Scanner scan) {
        try {
            Timestamp reportTime;
            CallableStatement generateReport = conn.prepareCall("{ ? = call arbordb.generateReport( ?, ?, ?) }");
            //prompt the user to enter the Sensor ID if -1 is entered they need to be returned to the main menu if a valid sensor ID is in goto next step
            int sensorId = getUserInputInt("Enter the sensor ID: ", scan);
            if(sensorId == -1){
                System.out.println("\nReturning to main menu\n");
                return;
            }
            //Check to see if the sensor ID is valid
            Statement checkSensorId = conn.createStatement();
            String query = "SELECT * FROM arbordb.SENSOR WHERE sensor_id = "+sensorId;
            ResultSet result = checkSensorId.executeQuery(query);
            if(result == null){
                System.out.println("\nInvalid Sensor ID\n");
                generateReport(conn, scan);
                return;
            }
            //prompt the user for the report time needs to be type timestamp
            String timeStampInput = getUserInputString("Enter the report timeStamp: ", scan);
            try {
            reportTime = Timestamp.valueOf(timeStampInput);
            } catch (IllegalArgumentException err) {
                System.out.println("Invalid Timestamp. Must be in the format yyyy-mm-dd hh:mm:ss");
                generateReport(conn, scan);
                return;
            }    
            //ask the user for the temperature:
            float temperature = getUserInputFloat("Enter the temperature: ", scan);
            //call generateReport as a prepared statement
            generateReport.registerOutParameter(1, Types.OTHER);
            generateReport.setInt(2, sensorId);
            generateReport.setTimestamp(3, reportTime);
            generateReport.setFloat(4, temperature);
            generateReport.execute();
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        } 
    }

    //#17
    public void rankForestSensors(Connection conn, Scanner scan) {
        try {
            Statement rankForestSensors = conn.createStatement();

            String query = "SELECT * FROM arbordb.rankForestSensors()";
            rankForestSensors.executeQuery(query);
            
            ResultSet result = rankForestSensors.getResultSet();

            if (result == null){
                System.out.println("No Forests to Rank");
            }

            System.out.printf("%-20s | %-8s%n", "forest_name", "sensors");
            System.out.println("-------------------------------------------");
            while(result.next()){
                String forest_name = result.getString("forest_name");
                int sensors = result.getInt("sensors");

                System.out.printf("%-20s | %-8d%n", forest_name, sensors);
            }
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        } 
    }

    //#18
    public void habitableEnvironment(Connection conn, Scanner scan) {
        try {
            Statement habitableEnvironment = conn.createStatement();
            String genusParam = getUserInputString("Enter the genus: ", scan);
            String epithetParam = getUserInputString("Enter the epithet: ", scan);
            int kParam = getUserInputInt("Enter k: ", scan);
            String query = "SELECT * FROM arbordb.habitableEnvironment('"+genusParam+"', '"+epithetParam+"', '"+kParam+"')";
            habitableEnvironment.executeQuery(query);
            
            ResultSet result = habitableEnvironment.getResultSet();

            if (result == null){
                System.out.println("No habitable environments were found");
            }

            System.out.println("forest_no     name     area      acid_level       MBR_XMin    MBR_XMax    MBR_YMin    MBR_YMax");
            System.out.println("---------------------------------------------------------------------------------------------");
            while(result.next()){
                int forest_no = result.getInt("forest_no");
                String name = result.getString("name");
                int area = result.getInt("area");
                float acid_level = result.getFloat("acid_level");

                float MBR_XMin = result.getFloat("MBR_XMin");
                float MBR_XMax = result.getFloat("MBR_XMax");
                float MBR_YMin = result.getFloat("MBR_YMin");
                float MBR_YMax = result.getFloat("MBR_YMax");

                System.out.println(forest_no + " | " + name + " | " + area + " | " + acid_level + " | " + MBR_XMin + " | " + MBR_XMax + " | " + MBR_YMin + " | " + MBR_YMax);
            }
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        } 
    }

    //#20
    public void threeDegrees(Connection conn, Scanner scan) {
        try {
            CallableStatement threeDegrees = conn.prepareCall("{ ? = call arbordb.threeDegrees( ?, ? ) }");
            threeDegrees.registerOutParameter(1, Types.VARCHAR);
            threeDegrees.setInt(2, getUserInputInt("Enter the the first tree number: ", scan));
            threeDegrees.setInt(3, getUserInputInt("Enter the second tree number: ", scan));
            threeDegrees.execute();
            String line = threeDegrees.getString(1);
            System.out.println("The path is: " + line);
        } catch (SQLException err) {
            System.out.println("SQL Error");
            while(err != null) {
                System.out.println("Message = " + err.getMessage());
                System.out.println("SQLState = " + err.getSQLState());
                System.out.println("SQL Code = " + err.getErrorCode());
                err = err.getNextException();
            }
        } 
    }

    public String uiInput(Scanner scan) {
        //System.out.println("Welcome to the Arbor Database Client!\nEnter the number of the operation you would like to perform.\n1.) Add new worker\n2.) Delete a worker\n3.) Employ a worker\n4.) Place a sensor\n5.) Move sensor\n6.) See top sensors\n7.) Locate tree species\n8.) Add a Forest\n9.) Add a tree species\n10.) Add a tree species to a forest\n11.) Remove a species from a forest\n12.) Remove an employed worker from a state\n13.) Delete sensor\n14.) List all sensors in a forest\nEnter exit to exit");
        System.out.println(" _____________________________________");
        System.out.println("|Welcome to the Arbor Database Client |");
        System.out.println("|_____________________________________|");
        System.out.println("Please Enter the number of the operation you would like to perform.\n1.) Add a Forest                                    2.) Add a tree species\n3.) Add a tree species to a forest                  4.) Add a new worker\n5.) Employ a worker to a state                      6.) Place a sensor\n7.) Generate a report                               8.) Remove a species from a forest\n9.) Delete a worker                                 10.) Move sensor\n11.) Remove a employed worker from a state          12.) Delete sensor\n13.) List all sensors in a forest                   14.) List sensors a worker in maintaining\n15.) Locate tree species                            16.) Display forests ranked on amount of sensors\n17.) Find habitable environment for a species       18.) See top sensors\n19.) Find a path between two forest less than 3 degrees apart\nEnter exit to exit");
        return scan.nextLine();
    }

    public static void main(String[] args) throws
        ClassNotFoundException {
        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            System.out.println("PostgreSQL JDBC Driver not found. Check to ensure the library is correctly loaded and try again.");
            return;
        }
        Scanner scan = new Scanner(System.in);
        ArborDB arbor = new ArborDB();

        String url = "jdbc:postgresql://localhost:5432/";
        Properties props = new Properties();
        props.setProperty("escapeSyntaxCallMode", "callIfNoReturn");
        Connection conn = arbor.connect(url, props, scan);
        
        String userInput = arbor.uiInput(scan);
        while(!userInput.toLowerCase().equals("exit"))
        {
            switch(userInput) {
                case "1":
                    arbor.addForest(conn, scan);
                break;
                case "2":
                    arbor.addTreeSpecies(conn, scan);
                break;
                case "3":
                    arbor.addSpeciesToForest(conn, scan);
                break;
                case "4":
                    arbor.newWorker(conn, scan);
                break;
                case "5":
                    arbor.employWorkerToState(conn, scan);
                break;
                case "6":
                    arbor.placeSensor(conn, scan);
                break;
                case "7":
                    arbor.generateReport(conn, scan);
                break;
                case "8":
                    arbor.removeSpeciesfromForest(conn, scan);
                break;
                case "9":
                    arbor.deleteWorker(conn, scan);
                break;
                case "10":
                    arbor.moveSensor(conn, scan);
                break;
                case "11":
                    arbor.removeWorkerFromState(conn, scan);
                break;
                case "12":
                    arbor.removeSensor(conn, scan);
                break;
                case "13":
                    arbor.listSensors(conn, scan);
                break;
                case "14":
                    arbor.listMaintainedSensors(conn, scan);
                break;
                case "15":
                    arbor.locateTreeSpecies(conn, scan);
                break;
                case "16":
                    arbor.rankForestSensors(conn, scan);
                break;
                case "17":
                    arbor.habitableEnvironment(conn, scan);
                break;
                case "18":
                    arbor.topSensors(conn, scan);
                break;
                case "19":
                    arbor.threeDegrees(conn, scan);
                break;
                default:
                    System.out.println("Invalid Input please try again");
            }
            userInput = arbor.uiInput(scan);
        }
        System.out.println("Goodbye");
        try {
            conn.close();
            } catch (SQLException err) {
                System.out.println("Error disconnecting from the Databse");
            }
        scan.close();
    }
}
