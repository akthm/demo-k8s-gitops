import java.sql.*;

public class DropKeycloakTables {
    public static void main(String[] args) {
        if (args.length != 3) {
            System.err.println("Usage: java DropKeycloakTables <jdbc-url> <username> <password>");
            System.exit(1);
        }
        
        String jdbcUrl = args[0];
        String username = args[1];
        String password = args[2];
        
        try (Connection conn = DriverManager.getConnection(jdbcUrl, username, password)) {
            System.out.println("Connected to database successfully");
            
            // Get all tables into a list first
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT table_name FROM user_tables ORDER BY table_name");
            
            java.util.List<String> tables = new java.util.ArrayList<>();
            while (rs.next()) {
                tables.add(rs.getString(1));
            }
            rs.close();
            
            System.out.println("\n=== Dropping " + tables.size() + " tables ===");
            for (String tableName : tables) {
                try {
                    stmt.executeUpdate("DROP TABLE " + tableName + " CASCADE CONSTRAINTS PURGE");
                    System.out.println("✓ Dropped: " + tableName);
                } catch (SQLException e) {
                    System.err.println("✗ Failed to drop " + tableName + ": " + e.getMessage());
                }
            }
            
            stmt.close();
            
            System.out.println("\n=== Verification ===");
            stmt = conn.createStatement();
            rs = stmt.executeQuery("SELECT COUNT(*) FROM user_tables");
            if (rs.next()) {
                int count = rs.getInt(1);
                System.out.println("Remaining tables: " + count);
                if (count == 0) {
                    System.out.println("✓ All tables dropped successfully!");
                }
            }
            
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
}
