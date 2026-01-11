const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

class BitwardenPrometheusScanner {
    constructor() {
        this.bitwardenUrl = process.env.BITWARDEN_URL || 'https://vault.corp.swayn.com';
        this.username = process.env.BITWARDEN_USERNAME;
        this.password = process.env.BITWARDEN_PASSWORD;
        this.prometheusConfigPath = process.env.PROMETHEUS_CONFIG_PATH || '/etc/prometheus/prometheus.yml';
        this.scanInterval = 60 * 1000; // 1 minute
        this.lastScanHash = null;

        if (!this.username || !this.password) {
            console.error('BITWARDEN_USERNAME and BITWARDEN_PASSWORD environment variables are required');
            process.exit(1);
        }
    }

    async run() {
        console.log('🚀 Starting Bitwarden Prometheus Scanner...');
        console.log(`📊 Scanning every ${this.scanInterval / 1000} seconds`);

        // Initial scan
        await this.scanAndUpdate();

        // Set up periodic scanning
        setInterval(async () => {
            await this.scanAndUpdate();
        }, this.scanInterval);
    }

    async scanAndUpdate() {
        try {
            console.log('🔍 Scanning Bitwarden entries...');

            // Login to Bitwarden (if not already logged in)
            await this.ensureBitwardenLogin();

            // Get all items with URIs
            const items = await this.getBitwardenItemsWithURIs();

            // Check if anything changed
            const currentHash = this.generateItemsHash(items);
            if (currentHash === this.lastScanHash) {
                console.log('✅ No changes detected in Bitwarden entries');
                return;
            }

            console.log(`📋 Found ${items.length} items with URIs`);

            // Generate Prometheus targets from Bitwarden entries
            const targets = this.generatePrometheusTargets(items);

            // Update Prometheus configuration
            await this.updatePrometheusConfig(targets);

            // Reload Prometheus
            await this.reloadPrometheus();

            this.lastScanHash = currentHash;
            console.log('✅ Prometheus configuration updated successfully');

        } catch (error) {
            console.error('❌ Error during scan:', error.message);
        }
    }

    async ensureBitwardenLogin() {
        try {
            // Check if already logged in
            execSync('bw status', { stdio: 'pipe' });
            console.log('🔑 Already logged in to Bitwarden');
        } catch (error) {
            // Not logged in, attempt login
            console.log('🔐 Logging in to Bitwarden...');
            try {
                execSync(`bw config server ${this.bitwardenUrl}`, { stdio: 'pipe' });
                execSync(`bw login ${this.username} ${this.password} --raw`, { stdio: 'pipe' });
                console.log('✅ Successfully logged in to Bitwarden');
            } catch (loginError) {
                throw new Error(`Failed to login to Bitwarden: ${loginError.message}`);
            }
        }
    }

    async getBitwardenItemsWithURIs() {
        try {
            const output = execSync('bw list items --pretty', { encoding: 'utf8' });
            const items = JSON.parse(output);

            // Filter items that have URIs
            return items.filter(item =>
                item.login &&
                item.login.uris &&
                item.login.uris.length > 0 &&
                item.name
            );
        } catch (error) {
            throw new Error(`Failed to get Bitwarden items: ${error.message}`);
        }
    }

    generateItemsHash(items) {
        const content = items.map(item => `${item.name}:${item.login.uris.map(u => u.uri).join(',')}`).join('|');
        let hash = 0;
        for (let i = 0; i < content.length; i++) {
            const char = content.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash; // Convert to 32-bit integer
        }
        return hash.toString();
    }

    generatePrometheusTargets(items) {
        const targets = [];

        items.forEach(item => {
            item.login.uris.forEach(uri => {
                try {
                    // Parse the URI to extract host and port
                    const url = new URL(uri.uri);

                    // Only include HTTP/HTTPS URIs
                    if (url.protocol === 'http:' || url.protocol === 'https:') {
                        const host = url.hostname;
                        const port = url.port || (url.protocol === 'https:' ? '443' : '80');

                        targets.push({
                            job_name: this.sanitizeJobName(item.name),
                            target_url: `${host}:${port}`,
                            labels: {
                                bitwarden_item: item.name,
                                source: 'bitwarden'
                            }
                        });
                    }
                } catch (error) {
                    console.warn(`⚠️  Skipping invalid URI: ${uri.uri}`);
                }
            });
        });

        return targets;
    }

    sanitizeJobName(name) {
        // Sanitize job name for Prometheus (alphanumeric, underscore, dash only)
        return name
            .toLowerCase()
            .replace(/[^a-z0-9_-]/g, '_')
            .replace(/_+/g, '_')
            .replace(/^_|_$/g, '')
            .substring(0, 50); // Limit length
    }

    async updatePrometheusConfig(targets) {
        try {
            // Read current config
            let config = fs.readFileSync(this.prometheusConfigPath, 'utf8');

            // Remove existing bitwarden-generated targets
            config = this.removeBitwardenTargets(config);

            // Add new targets
            config = this.addBitwardenTargets(config, targets);

            // Write updated config
            fs.writeFileSync(this.prometheusConfigPath, config, 'utf8');
            console.log(`📝 Updated Prometheus config with ${targets.length} Bitwarden targets`);

        } catch (error) {
            throw new Error(`Failed to update Prometheus config: ${error.message}`);
        }
    }

    removeBitwardenTargets(config) {
        const lines = config.split('\n');
        const filteredLines = [];
        let skipBlock = false;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];

            // Check for bitwarden-generated job blocks
            if (line.includes('job_name:') && line.includes('bitwarden_')) {
                skipBlock = true;
                // Skip until next job_name or end of scrape_configs
                while (i < lines.length && !lines[i].match(/^  - job_name:/) && !lines[i].includes('scrape_configs:')) {
                    i++;
                }
                i--; // Adjust for loop increment
                skipBlock = false;
                continue;
            }

            if (!skipBlock) {
                filteredLines.push(line);
            }
        }

        return filteredLines.join('\n');
    }

    addBitwardenTargets(config, targets) {
        if (targets.length === 0) {
            return config;
        }

        // Find scrape_configs section
        const lines = config.split('\n');
        let insertIndex = -1;

        for (let i = 0; i < lines.length; i++) {
            if (lines[i].includes('scrape_configs:')) {
                // Find where to insert (after existing jobs)
                let j = i + 1;
                while (j < lines.length && (lines[j].startsWith(' ') || lines[j].trim() === '')) {
                    if (lines[j].match(/^  - job_name:/)) {
                        // Find the end of this job block
                        while (j < lines.length && (lines[j].startsWith(' ') || lines[j].trim() === '')) {
                            j++;
                        }
                    } else {
                        j++;
                    }
                }
                insertIndex = j;
                break;
            }
        }

        if (insertIndex === -1) {
            throw new Error('Could not find scrape_configs section in Prometheus config');
        }

        // Generate YAML for new targets
        const targetYaml = targets.map(target => {
            let yaml = `  - job_name: bitwarden_${target.job_name}\n`;
            yaml += `    static_configs:\n`;
            yaml += `      - targets: ['${target.target_url}']\n`;

            if (target.labels && Object.keys(target.labels).length > 0) {
                yaml += `    labels:\n`;
                Object.entries(target.labels).forEach(([key, value]) => {
                    yaml += `      ${key}: "${value}"\n`;
                });
            }

            return yaml;
        }).join('\n');

        // Insert into config
        lines.splice(insertIndex, 0, targetYaml);

        return lines.join('\n');
    }

    async reloadPrometheus() {
        try {
            console.log('🔄 Reloading Prometheus configuration...');

            // Use curl to trigger Prometheus reload
            execSync(`curl -X POST http://prometheus:9090/-/reload`, { stdio: 'pipe' });

            console.log('✅ Prometheus reloaded successfully');
        } catch (error) {
            throw new Error(`Failed to reload Prometheus: ${error.message}`);
        }
    }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('🛑 Shutting down Bitwarden Prometheus Scanner...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('🛑 Shutting down Bitwarden Prometheus Scanner...');
    process.exit(0);
});

// Start the scanner
const scanner = new BitwardenPrometheusScanner();
scanner.run().catch(error => {
    console.error('💥 Fatal error:', error);
    process.exit(1);
});