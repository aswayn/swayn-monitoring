<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Swayn Monitoring - Configuration</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2em;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .content {
            padding: 20px;
        }
        .section {
            margin-bottom: 30px;
        }
        .section h2 {
            color: #667eea;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .target-list {
            display: grid;
            gap: 15px;
        }
        .target-item {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 5px;
            padding: 15px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .target-info h3 {
            margin: 0 0 5px 0;
            color: #495057;
        }
        .target-url {
            color: #6c757d;
            font-family: monospace;
        }
        .target-status {
            padding: 5px 10px;
            border-radius: 15px;
            font-size: 0.8em;
            font-weight: bold;
        }
        .status-enabled {
            background: #d4edda;
            color: #155724;
        }
        .status-disabled {
            background: #f8d7da;
            color: #721c24;
        }
        .btn {
            padding: 8px 16px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            font-size: 14px;
            transition: background-color 0.3s;
        }
        .btn-primary {
            background: #007bff;
            color: white;
        }
        .btn-primary:hover {
            background: #0056b3;
        }
        .btn-success {
            background: #28a745;
            color: white;
        }
        .btn-success:hover {
            background: #1e7e34;
        }
        .btn-danger {
            background: #dc3545;
            color: white;
        }
        .btn-danger:hover {
            background: #bd2130;
        }
        .btn-secondary {
            background: #6c757d;
            color: white;
        }
        .btn-secondary:hover {
            background: #545b62;
        }
        .form-group {
            margin-bottom: 15px;
        }
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        .form-group input, .form-group textarea {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
        }
        .form-group textarea {
            height: 80px;
            resize: vertical;
        }
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            z-index: 1000;
        }
        .modal-content {
            background: white;
            margin: 10% auto;
            padding: 20px;
            border-radius: 8px;
            width: 90%;
            max-width: 500px;
        }
        .modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        .modal-header h3 {
            margin: 0;
        }
        .close {
            cursor: pointer;
            font-size: 24px;
            color: #999;
        }
        .actions {
            margin-top: 20px;
            text-align: right;
        }
        .alert {
            padding: 10px;
            border-radius: 4px;
            margin-bottom: 15px;
        }
        .alert-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .alert-error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 Swayn Monitoring Configuration</h1>
            <p>Manage Prometheus targets and monitoring configuration</p>
        </div>

        <div class="content">
            <div id="alert-container"></div>

            <div class="section">
                <h2>📊 Prometheus Targets</h2>
                <button class="btn btn-primary" onclick="showAddModal()">+ Add New Target</button>
                <div id="targets-list" class="target-list">
                    <!-- Targets will be loaded here -->
                </div>
            </div>

            <div class="section">
                <h2>⚙️ Configuration Actions</h2>
                <button class="btn btn-success" onclick="generateConfig()">🔄 Generate Prometheus Config</button>
                <button class="btn btn-secondary" onclick="reloadPrometheus()">🔄 Reload Prometheus</button>
            </div>
        </div>
    </div>

    <!-- Add/Edit Target Modal -->
    <div id="target-modal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h3 id="modal-title">Add New Target</h3>
                <span class="close" onclick="closeModal()">&times;</span>
            </div>
            <form id="target-form">
                <input type="hidden" id="target-id" name="id">
                <div class="form-group">
                    <label for="job-name">Job Name:</label>
                    <input type="text" id="job-name" name="job_name" required>
                </div>
                <div class="form-group">
                    <label for="target-url">Target URL:</label>
                    <input type="text" id="target-url" name="target_url" placeholder="host:port" required>
                </div>
                <div class="form-group">
                    <label for="scrape-interval">Scrape Interval:</label>
                    <input type="text" id="scrape-interval" name="scrape_interval" value="15s">
                </div>
                <div class="form-group">
                    <label for="description">Description:</label>
                    <textarea id="description" name="description"></textarea>
                </div>
                <div class="form-group">
                    <label>
                        <input type="checkbox" id="enabled" name="enabled" checked> Enabled
                    </label>
                </div>
                <div class="actions">
                    <button type="button" class="btn btn-secondary" onclick="closeModal()">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Target</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        // Load targets on page load
        document.addEventListener('DOMContentLoaded', loadTargets);

        // Handle form submission
        document.getElementById('target-form').addEventListener('submit', function(e) {
            e.preventDefault();
            saveTarget();
        });

        function showAlert(message, type = 'success') {
            const alertContainer = document.getElementById('alert-container');
            alertContainer.innerHTML = `<div class="alert alert-${type}">${message}</div>`;
            setTimeout(() => alertContainer.innerHTML = '', 5000);
        }

        function loadTargets() {
            fetch('targets.php?action=list')
                .then(response => response.json())
                .then(data => {
                    const container = document.getElementById('targets-list');
                    container.innerHTML = '';

                    if (data.targets && data.targets.length > 0) {
                        data.targets.forEach(target => {
                            const statusClass = target.enabled ? 'status-enabled' : 'status-disabled';
                            const statusText = target.enabled ? 'Enabled' : 'Disabled';

                            container.innerHTML += `
                                <div class="target-item">
                                    <div class="target-info">
                                        <h3>${target.job_name}</h3>
                                        <div class="target-url">${target.target_url}</div>
                                        <div>Interval: ${target.scrape_interval} | <span class="target-status ${statusClass}">${statusText}</span></div>
                                    </div>
                                    <div>
                                        <button class="btn btn-secondary" onclick="editTarget(${target.id})">Edit</button>
                                        <button class="btn btn-danger" onclick="deleteTarget(${target.id}, '${target.job_name}')">Delete</button>
                                    </div>
                                </div>
                            `;
                        });
                    } else {
                        container.innerHTML = '<p>No targets configured yet.</p>';
                    }
                })
                .catch(error => {
                    console.error('Error loading targets:', error);
                    showAlert('Error loading targets', 'error');
                });
        }

        function showAddModal() {
            document.getElementById('modal-title').textContent = 'Add New Target';
            document.getElementById('target-form').reset();
            document.getElementById('target-id').value = '';
            document.getElementById('target-modal').style.display = 'block';
        }

        function editTarget(id) {
            fetch(`targets.php?action=get&id=${id}`)
                .then(response => response.json())
                .then(data => {
                    if (data.target) {
                        const target = data.target;
                        document.getElementById('modal-title').textContent = 'Edit Target';
                        document.getElementById('target-id').value = target.id;
                        document.getElementById('job-name').value = target.job_name;
                        document.getElementById('target-url').value = target.target_url;
                        document.getElementById('scrape-interval').value = target.scrape_interval;
                        document.getElementById('description').value = target.description || '';
                        document.getElementById('enabled').checked = target.enabled;
                        document.getElementById('target-modal').style.display = 'block';
                    }
                })
                .catch(error => {
                    console.error('Error loading target:', error);
                    showAlert('Error loading target', 'error');
                });
        }

        function saveTarget() {
            const formData = new FormData(document.getElementById('target-form'));
            const action = formData.get('id') ? 'update' : 'create';

            fetch('targets.php', {
                method: 'POST',
                body: new URLSearchParams({
                    action: action,
                    ...Object.fromEntries(formData)
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert(data.message);
                    closeModal();
                    loadTargets();
                } else {
                    showAlert(data.message || 'Error saving target', 'error');
                }
            })
            .catch(error => {
                console.error('Error saving target:', error);
                showAlert('Error saving target', 'error');
            });
        }

        function deleteTarget(id, jobName) {
            if (confirm(`Are you sure you want to delete the target "${jobName}"?`)) {
                fetch('targets.php', {
                    method: 'POST',
                    body: new URLSearchParams({
                        action: 'delete',
                        id: id
                    })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showAlert(data.message);
                        loadTargets();
                    } else {
                        showAlert(data.message || 'Error deleting target', 'error');
                    }
                })
                .catch(error => {
                    console.error('Error deleting target:', error);
                    showAlert('Error deleting target', 'error');
                });
            }
        }

        function generateConfig() {
            fetch('generate-config.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showAlert('Prometheus configuration generated successfully');
                    } else {
                        showAlert(data.message || 'Error generating configuration', 'error');
                    }
                })
                .catch(error => {
                    console.error('Error generating config:', error);
                    showAlert('Error generating configuration', 'error');
                });
        }

        function reloadPrometheus() {
            fetch('reload-prometheus.php')
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showAlert('Prometheus reloaded successfully');
                    } else {
                        showAlert(data.message || 'Error reloading Prometheus', 'error');
                    }
                })
                .catch(error => {
                    console.error('Error reloading Prometheus:', error);
                    showAlert('Error reloading Prometheus', 'error');
                });
        }

        function closeModal() {
            document.getElementById('target-modal').style.display = 'none';
        }

        // Close modal when clicking outside
        window.onclick = function(event) {
            const modal = document.getElementById('target-modal');
            if (event.target == modal) {
                modal.style.display = 'none';
            }
        }
    </script>
</body>
</html>