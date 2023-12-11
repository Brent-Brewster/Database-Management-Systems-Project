import java.util.NoSuchElementException;
import java.util.Scanner;

public class ConnectionConfig{

    private String user = "postgres";
    private String pass = "";
    private static final String USER_REQUEST_STR = "Enter the username for connecting to the database: ";
    private static final String PASS_REQUEST_STR = "Enter the password for connecting to the database: ";

    public ConnectionConfig(Scanner scanner){
        scanner = new Scanner(System.in);
        requestUsername(scanner);
        requestPassword(scanner);
    }

    public String getUser() {
        return user;
    }

    public String getPass() {
        return pass;
    }

    private String requestUserInput(String inputRequest, Scanner scanner){
        try {
            System.out.print(inputRequest);
            return scanner.nextLine();
        } catch (NoSuchElementException e) {
            System.out.println("No input detected.");
            return null;
        } catch (IllegalArgumentException e) {
            System.out.println("Scanner was likely closed before reading the user input.");
            return null;
        }
    }

    private void requestUsername(Scanner scanner){
        String userInput = requestUserInput(USER_REQUEST_STR, scanner);
        if (userInput != null) {
            user = userInput;
        }
    }

    private void requestPassword(Scanner scanner){
        String userInput = requestUserInput(PASS_REQUEST_STR, scanner);
        if (userInput != null) {
            pass = userInput;
        }
    }
}