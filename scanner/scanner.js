const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const { Etcd3 } = require('etcd3');

class BitwardenPrometheusScanner {
    constructor() {
        this.bitwardenUrl = process.env.BITWARDEN_URL || 'https://vault.corp.swayn.com';
        this.username = process.env.BITWARDEN_USERNAME;
        this.password = process.env.BITWARDEN_PASSWORD;
        this.etcdEndpoints = process.env.ETCD_ENDPOINTS || 'etcd:2379';
        this.etcdPrefix = process.env.ETCD_PREFIX || '/prometheus/targets/';
        this.scanInterval = 60 * 1000; // 1 minute
        this.lastScanHash = null;

        if (!this.username || !this.password) {
            console.error('BITWARDEN_USERNAME and BITWARDEN_PASSWORD environment variables are required');
            process.exit(1);
        }

        // Initialize etcd client
        this.etcd = new Etcd3({
            hosts: this.etcdEndpoints.split(','),
            dialTimeout: 3000,
        });
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

            // Update Prometheus configuration in etcd
            await this.updatePrometheusConfig(targets);

            // Note: No manual reload needed with service discovery

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

    async clearEtcdTargets() {
        try {
            // Delete all keys under the targets prefix
            await this.etcd.delete().prefix(this.etcdPrefix).exec();
            console.log('🧹 Cleared existing etcd targets');
        } catch (error) {
            console.warn('Warning: Failed to clear existing etcd targets:', error.message);
        }
    }

    async writeTargetsToEtcd(targets) {
        const operations = [];

        targets.forEach(target => {
            // Create etcd key in format: /prometheus/targets/{job_name}/{target_url}
            const key = `${this.etcdPrefix}${target.job_name}/${target.target_url}`;

            // Store target information as JSON
            const value = JSON.stringify({
                target: target.target_url,
                labels: target.labels || {}
            });

            operations.push({
                type: 'put',
                key: key,
                value: value
            });
        });

        if (operations.length > 0) {
            // Execute all put operations in a transaction
            await this.etcd.transaction()
                .If()
                .Then(...operations.map(op => this.etcd.put(op.key).value(op.value)))
                .Commit();

            console.log(`✅ Wrote ${operations.length} target entries to etcd`);
        }
    }

    async updatePrometheusConfig(targets) {
        try {
            // Clear existing targets in etcd
            await this.clearEtcdTargets();

            // Write new targets to etcd
            await this.writeTargetsToEtcd(targets);

            console.log(`📝 Updated etcd with ${targets.length} Bitwarden targets`);

        } catch (error) {
            throw new Error(`Failed to update etcd targets: ${error.message}`);
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