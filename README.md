# Database Systems Project
### Set up Instructions ###
1. Run the sql files in datagrip
2. Insert example data in the order of (State, Worker, Employed, Sensor, Tree_Species, Tree_Common_Name, phone...)
### Compilation Instructions ###
1. Compile the code on windows using: javac -cp "postgresql-42.6.0.jar;." ArborDB.java
2. Run ArborDB.java on windows using: java -cp "postgresql-42.6.0.jar;." ArborDB
#### Use of the application ####
After the application is run you will be prompted to enter a username and password. These correspond to the username you selected when setting up PostgreSQL, (username is postgres by default). If you enter an invalid username or password you will be prompted to try again until you enter a valid username and password that results in a successful connection with the database. Once connected you will be presented the ArborDB UI. It will offer you enumerated opptions that perform all of the functions outlined in project-p3-1.pdf. To perform an action enter the number that appears to the left of it, then press enter. From there follow the prompts. To exit the application cleanly simply enter exit into the main UI prompt. 
