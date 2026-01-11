const express = require('express');
const { Etcd3 } = require('etcd3');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const cors = require('cors');
const helmet = require('helmet');

const app = express();
const port = process.env.PORT || 3002;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// etcd client
const etcd = new Etcd3({
    hosts: process.env.ETCD_ENDPOINTS ? process.env.ETCD_ENDPOINTS.split(',') : ['etcd:2379'],
});

// Key prefixes for etcd
const KEYPairs_PREFIX = '/keypairs/';
const USERS_PREFIX = '/users/';

// Authentication middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }

    jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', (err, user) => {
        if (err) {
            return res.status(403).json({ error: 'Invalid token' });
        }
        req.user = user;
        next();
    });
};

// Initialize default admin user
async function initDefaultUser() {
    try {
        const adminKey = `${USERS_PREFIX}admin`;
        const existing = await etcd.get(adminKey).string();

        if (!existing) {
            // Create default admin user (password: admin123)
            const passwordHash = await bcrypt.hash('admin123', 12);
            const userData = JSON.stringify({
                username: 'admin',
                passwordHash: passwordHash,
                role: 'admin',
                createdAt: new Date().toISOString()
            });

            await etcd.put(adminKey).value(userData);
            console.log('✅ Default admin user created');
        }
    } catch (error) {
        console.error('❌ Failed to initialize default user:', error);
    }
}

// Generate SSH keypair
app.post('/api/keys/generate-ssh', authenticateToken, async (req, res) => {
    try {
        const { name, passphrase, keySize = 2048 } = req.body;

        if (!name) {
            return res.status(400).json({ error: 'Key name is required' });
        }

        // Check if key already exists
        const keyKey = `${KEYPairs_PREFIX}${name}`;
        const existing = await etcd.get(keyKey).string();
        if (existing) {
            return res.status(409).json({ error: 'Keypair with this name already exists' });
        }

        // Generate SSH keypair
        const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
            modulusLength: keySize,
            publicKeyEncoding: {
                type: 'spki',
                format: 'pem'
            },
            privateKeyEncoding: {
                type: 'pkcs8',
                format: 'pem'
            }
        });

        // Encrypt private key if passphrase provided
        let encryptedPrivateKey = null;
        let passphraseHash = null;

        if (passphrase) {
            const saltRounds = 12;
            passphraseHash = await bcrypt.hash(passphrase, saltRounds);

            // Encrypt private key with passphrase
            const cipher = crypto.createCipher('aes-256-cbc', passphrase);
            encryptedPrivateKey = cipher.update(privateKey, 'utf8', 'hex') + cipher.final('hex');
        }

        // Store in etcd
        const keyData = JSON.stringify({
            name: name,
            type: 'ssh',
            publicKey: publicKey,
            privateKey: passphrase ? null : privateKey,
            encryptedPrivateKey: encryptedPrivateKey,
            passphraseHash: passphraseHash,
            metadata: { keySize, generated: true },
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        });

        await etcd.put(keyKey).value(keyData);

        res.status(201).json({
            success: true,
            keypair: {
                name: name,
                type: 'ssh',
                createdAt: new Date().toISOString()
            },
            publicKey: publicKey
        });

    } catch (error) {
        console.error('Error generating SSH key:', error);
        res.status(500).json({ error: 'Failed to generate SSH key' });
    }
});

// Get all keypairs (names and metadata only)
app.get('/api/keys', authenticateToken, async (req, res) => {
    try {
        const keys = await etcd.getAll().prefix(KEYPairs_PREFIX).keys();

        const keypairs = [];

        for (const key of keys) {
            try {
                const value = await etcd.get(key).string();
                const keyData = JSON.parse(value);

                keypairs.push({
                    name: keyData.name,
                    type: keyData.type,
                    metadata: keyData.metadata || {},
                    createdAt: keyData.createdAt,
                    updatedAt: keyData.updatedAt
                });
            } catch (parseError) {
                console.warn(`Skipping invalid key data for ${key}:`, parseError.message);
            }
        }

        res.json({
            success: true,
            keypairs: keypairs
        });
    } catch (error) {
        console.error('Error fetching keypairs:', error);
        res.status(500).json({ error: 'Failed to fetch keypairs' });
    }
});

// Get specific keypair
app.get('/api/keys/:name', authenticateToken, async (req, res) => {
    try {
        const { name } = req.params;
        const keyKey = `${KEYPairs_PREFIX}${name}`;

        const value = await etcd.get(keyKey).string();
        if (!value) {
            return res.status(404).json({ error: 'Keypair not found' });
        }

        const keyData = JSON.parse(value);

        // Don't return private keys in this endpoint
        const { privateKey, encryptedPrivateKey, passphraseHash, ...publicData } = keyData;

        res.json({
            success: true,
            keypair: publicData
        });
    } catch (error) {
        console.error('Error fetching keypair:', error);
        res.status(500).json({ error: 'Failed to fetch keypair' });
    }
});

// Get private key (requires passphrase if encrypted)
app.post('/api/keys/:name/private', authenticateToken, async (req, res) => {
    try {
        const { name } = req.params;
        const { passphrase } = req.body;
        const keyKey = `${KEYPairs_PREFIX}${name}`;

        const value = await etcd.get(keyKey).string();
        if (!value) {
            return res.status(404).json({ error: 'Keypair not found' });
        }

        const keyData = JSON.parse(value);

        let privateKey = keyData.privateKey;

        // If private key is encrypted, require passphrase
        if (keyData.encryptedPrivateKey && !keyData.privateKey) {
            if (!passphrase) {
                return res.status(400).json({ error: 'Passphrase required for encrypted key' });
            }

            // Verify passphrase
            const isValidPassphrase = await bcrypt.compare(passphrase, keyData.passphraseHash);
            if (!isValidPassphrase) {
                return res.status(401).json({ error: 'Invalid passphrase' });
            }

            // Decrypt private key
            const decipher = crypto.createDecipher('aes-256-cbc', passphrase);
            privateKey = decipher.update(keyData.encryptedPrivateKey, 'hex', 'utf8') + decipher.final('utf8');
        }

        if (!privateKey) {
            return res.status(404).json({ error: 'Private key not available' });
        }

        res.json({
            success: true,
            privateKey: privateKey
        });
    } catch (error) {
        console.error('Error fetching private key:', error);
        res.status(500).json({ error: 'Failed to fetch private key' });
    }
});

// Update keypair metadata
app.put('/api/keys/:name', authenticateToken, async (req, res) => {
    try {
        const { name } = req.params;
        const { metadata } = req.body;
        const keyKey = `${KEYPairs_PREFIX}${name}`;

        const value = await etcd.get(keyKey).string();
        if (!value) {
            return res.status(404).json({ error: 'Keypair not found' });
        }

        const keyData = JSON.parse(value);
        keyData.metadata = metadata || {};
        keyData.updatedAt = new Date().toISOString();

        await etcd.put(keyKey).value(JSON.stringify(keyData));

        res.json({
            success: true,
            keypair: {
                name: keyData.name,
                type: keyData.type,
                metadata: keyData.metadata,
                updatedAt: keyData.updatedAt
            }
        });
    } catch (error) {
        console.error('Error updating keypair:', error);
        res.status(500).json({ error: 'Failed to update keypair' });
    }
});

// Delete keypair
app.delete('/api/keys/:name', authenticateToken, async (req, res) => {
    try {
        const { name } = req.params;
        const keyKey = `${KEYPairs_PREFIX}${name}`;

        const value = await etcd.get(keyKey).string();
        if (!value) {
            return res.status(404).json({ error: 'Keypair not found' });
        }

        await etcd.delete().key(keyKey);

        res.json({
            success: true,
            message: `Keypair '${name}' deleted successfully`
        });
    } catch (error) {
        console.error('Error deleting keypair:', error);
        res.status(500).json({ error: 'Failed to delete keypair' });
    }
});

// Login endpoint
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Username and password required' });
        }

        // Get user from etcd
        const userKey = `${USERS_PREFIX}${username}`;
        const userDataStr = await etcd.get(userKey).string();

        if (!userDataStr) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const userData = JSON.parse(userDataStr);

        // Verify password
        const isValidPassword = await bcrypt.compare(password, userData.passwordHash);
        if (!isValidPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Generate JWT token
        const token = jwt.sign(
            { id: userData.username, username: userData.username, role: userData.role },
            process.env.JWT_SECRET || 'your-secret-key',
            { expiresIn: '24h' }
        );

        res.json({
            success: true,
            token: token,
            user: {
                username: userData.username,
                role: userData.role
            }
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Authentication failed' });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', service: 'etcd-keypair-service' });
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Unhandled error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
async function startServer() {
    try {
        // Test etcd connection
        await etcd.get('/health').string();
        console.log('✅ Connected to etcd');

        // Initialize default user
        await initDefaultUser();

        app.listen(port, () => {
            console.log(`🔑 etcd Keypair Service listening on port ${port}`);
            console.log(`🔗 Connected to etcd at ${process.env.ETCD_ENDPOINTS || 'etcd:2379'}`);
        });
    } catch (error) {
        console.error('❌ Failed to connect to etcd:', error.message);
        process.exit(1);
    }
}

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('🛑 Shutting down etcd Keypair Service...');
    await etcd.close();
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('🛑 Shutting down etcd Keypair Service...');
    await etcd.close();
    process.exit(0);
});

startServer().catch(console.error);