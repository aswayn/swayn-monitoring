<?php
header('Content-Type: application/json');
require_once 'config.php';

$action = $_REQUEST['action'] ?? '';

switch ($action) {
    case 'list':
        listTargets();
        break;
    case 'get':
        getTarget();
        break;
    case 'create':
        createTarget();
        break;
    case 'update':
        updateTarget();
        break;
    case 'delete':
        deleteTarget();
        break;
    default:
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        break;
}

function listTargets() {
    try {
        $pdo = getDbConnection();
        $stmt = $pdo->query("SELECT * FROM monitoring.prometheus_targets ORDER BY job_name");
        $targets = $stmt->fetchAll();

        echo json_encode(['success' => true, 'targets' => $targets]);
    } catch (Exception $e) {
        echo json_encode(['success' => false, 'message' => 'Error loading targets: ' . $e->getMessage()]);
    }
}

function getTarget() {
    $id = (int)($_GET['id'] ?? 0);

    if (!$id) {
        echo json_encode(['success' => false, 'message' => 'Invalid target ID']);
        return;
    }

    try {
        $pdo = getDbConnection();
        $stmt = $pdo->prepare("SELECT * FROM monitoring.prometheus_targets WHERE id = ?");
        $stmt->execute([$id]);
        $target = $stmt->fetch();

        if ($target) {
            echo json_encode(['success' => true, 'target' => $target]);
        } else {
            echo json_encode(['success' => false, 'message' => 'Target not found']);
        }
    } catch (Exception $e) {
        echo json_encode(['success' => false, 'message' => 'Error loading target: ' . $e->getMessage()]);
    }
}

function createTarget() {
    $data = [
        'job_name' => trim($_POST['job_name'] ?? ''),
        'target_url' => trim($_POST['target_url'] ?? ''),
        'scrape_interval' => trim($_POST['scrape_interval'] ?? '15s'),
        'scrape_timeout' => '10s',
        'enabled' => isset($_POST['enabled']) ? true : false,
        'description' => trim($_POST['description'] ?? '')
    ];

    // Validation
    if (empty($data['job_name']) || empty($data['target_url'])) {
        echo json_encode(['success' => false, 'message' => 'Job name and target URL are required']);
        return;
    }

    // Validate scrape interval format
    if (!preg_match('/^\d+[smhd]$/', $data['scrape_interval'])) {
        $data['scrape_interval'] = '15s';
    }

    try {
        $pdo = getDbConnection();

        // Check if job_name already exists
        $stmt = $pdo->prepare("SELECT id FROM monitoring.prometheus_targets WHERE job_name = ?");
        $stmt->execute([$data['job_name']]);
        if ($stmt->fetch()) {
            echo json_encode(['success' => false, 'message' => 'Job name already exists']);
            return;
        }

        $stmt = $pdo->prepare("
            INSERT INTO monitoring.prometheus_targets
            (job_name, target_url, scrape_interval, scrape_timeout, enabled, description)
            VALUES (?, ?, ?, ?, ?, ?)
        ");
        $stmt->execute([
            $data['job_name'],
            $data['target_url'],
            $data['scrape_interval'],
            $data['scrape_timeout'],
            $data['enabled'],
            $data['description']
        ]);

        echo json_encode(['success' => true, 'message' => 'Target created successfully']);
    } catch (Exception $e) {
        echo json_encode(['success' => false, 'message' => 'Error creating target: ' . $e->getMessage()]);
    }
}

function updateTarget() {
    $id = (int)($_POST['id'] ?? 0);
    $data = [
        'job_name' => trim($_POST['job_name'] ?? ''),
        'target_url' => trim($_POST['target_url'] ?? ''),
        'scrape_interval' => trim($_POST['scrape_interval'] ?? '15s'),
        'enabled' => isset($_POST['enabled']) ? true : false,
        'description' => trim($_POST['description'] ?? '')
    ];

    if (!$id || empty($data['job_name']) || empty($data['target_url'])) {
        echo json_encode(['success' => false, 'message' => 'Invalid data provided']);
        return;
    }

    // Validate scrape interval format
    if (!preg_match('/^\d+[smhd]$/', $data['scrape_interval'])) {
        $data['scrape_interval'] = '15s';
    }

    try {
        $pdo = getDbConnection();

        // Check if job_name conflicts with another target
        $stmt = $pdo->prepare("SELECT id FROM monitoring.prometheus_targets WHERE job_name = ? AND id != ?");
        $stmt->execute([$data['job_name'], $id]);
        if ($stmt->fetch()) {
            echo json_encode(['success' => false, 'message' => 'Job name already exists']);
            return;
        }

        $stmt = $pdo->prepare("
            UPDATE monitoring.prometheus_targets
            SET job_name = ?, target_url = ?, scrape_interval = ?, enabled = ?, description = ?, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        ");
        $stmt->execute([
            $data['job_name'],
            $data['target_url'],
            $data['scrape_interval'],
            $data['enabled'],
            $data['description'],
            $id
        ]);

        echo json_encode(['success' => true, 'message' => 'Target updated successfully']);
    } catch (Exception $e) {
        echo json_encode(['success' => false, 'message' => 'Error updating target: ' . $e->getMessage()]);
    }
}

function deleteTarget() {
    $id = (int)($_POST['id'] ?? 0);

    if (!$id) {
        echo json_encode(['success' => false, 'message' => 'Invalid target ID']);
        return;
    }

    try {
        $pdo = getDbConnection();
        $stmt = $pdo->prepare("DELETE FROM monitoring.prometheus_targets WHERE id = ?");
        $stmt->execute([$id]);

        echo json_encode(['success' => true, 'message' => 'Target deleted successfully']);
    } catch (Exception $e) {
        echo json_encode(['success' => false, 'message' => 'Error deleting target: ' . $e->getMessage()]);
    }
}
?>