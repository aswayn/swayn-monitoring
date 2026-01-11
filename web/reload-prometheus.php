<?php
header('Content-Type: application/json');

// Function to reload Prometheus configuration
function reloadPrometheus() {
    $prometheusUrl = 'http://prometheus:9090/-/reload';

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $prometheusUrl);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);

    if ($error) {
        return ['success' => false, 'message' => 'Curl error: ' . $error];
    }

    if ($httpCode === 200) {
        return ['success' => true, 'message' => 'Prometheus configuration reloaded successfully'];
    } else {
        return ['success' => false, 'message' => 'Prometheus reload failed with HTTP code: ' . $httpCode];
    }
}

// Alternative method using POST to /-/reload endpoint
function reloadPrometheusAlternative() {
    // This would be used if the first method doesn't work
    // Prometheus needs to be started with --web.enable-lifecycle
    return reloadPrometheus();
}

try {
    $result = reloadPrometheus();
    echo json_encode($result);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'Error reloading Prometheus: ' . $e->getMessage()]);
}
?>