<?php
// Database configuration
define('DB_HOST', getenv('POSTGRES_HOST') ?: 'postgres');
define('DB_NAME', getenv('POSTGRES_DB') ?: 'monitoring');
define('DB_USER', getenv('POSTGRES_USER') ?: 'monitoring_user');
define('DB_PASS', getenv('POSTGRES_PASSWORD') ?: 'monitoring_pass');

// Function to get database connection
function getDbConnection() {
    try {
        $dsn = "pgsql:host=" . DB_HOST . ";dbname=" . DB_NAME;
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        return $pdo;
    } catch (PDOException $e) {
        die("Database connection failed: " . $e->getMessage());
    }
}
?>