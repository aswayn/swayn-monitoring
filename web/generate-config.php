<?php
header('Content-Type: application/json');
require_once 'config.php';

try {
    $pdo = getDbConnection();

    // Get all enabled targets
    $stmt = $pdo->query("
        SELECT job_name, target_url, scrape_interval, scrape_timeout, labels
        FROM monitoring.prometheus_targets
        WHERE enabled = true
        ORDER BY job_name
    ");
    $targets = $stmt->fetchAll();

    // Generate Prometheus configuration
    $config = generatePrometheusConfig($targets);

    // Write to file (you might want to make this configurable)
    $configPath = '/tmp/prometheus-generated.yml';
    if (file_put_contents($configPath, $config)) {
        echo json_encode([
            'success' => true,
            'message' => 'Configuration generated successfully',
            'config_path' => $configPath,
            'targets_count' => count($targets)
        ]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to write configuration file']);
    }

} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'Error generating configuration: ' . $e->getMessage()]);
}

function generatePrometheusConfig($targets) {
    $config = "# Generated Prometheus Configuration\n";
    $config .= "# Generated at: " . date('Y-m-d H:i:s T') . "\n\n";

    $config .= "global:\n";
    $config .= "  scrape_interval: 15s\n";
    $config .= "  evaluation_interval: 15s\n\n";

    $config .= "rule_files:\n";
    $config .= "  # - \"first_rules.yml\"\n";
    $config .= "  # - \"second_rules.yml\"\n\n";

    $config .= "scrape_configs:\n";

    foreach ($targets as $target) {
        $config .= "  - job_name: '{$target['job_name']}'\n";
        $config .= "    static_configs:\n";
        $config .= "      - targets: ['{$target['target_url']}']\n";

        if ($target['scrape_interval'] !== '15s') {
            $config .= "    scrape_interval: {$target['scrape_interval']}\n";
        }

        if ($target['scrape_timeout'] !== '10s') {
            $config .= "    scrape_timeout: {$target['scrape_timeout']}\n";
        }

        // Add labels if they exist
        $labels = json_decode($target['labels'], true);
        if (!empty($labels)) {
            $config .= "    labels:\n";
            foreach ($labels as $key => $value) {
                $config .= "      {$key}: \"{$value}\"\n";
            }
        }

        $config .= "\n";
    }

    return $config;
}
?>