const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3001;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Database connection
const pool = new Pool({
    host: process.env.POSTGRES_HOST || 'postgres',
    database: process.env.POSTGRES_DB || 'monitoring',
    user: process.env.POSTGRES_USER || 'monitoring_user',
    password: process.env.POSTGRES_PASSWORD || 'monitoring_pass',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

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

// Initialize database tables
async function initDatabase() {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS keypairs (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL UNIQUE,
                type VARCHAR(50) NOT NULL, -- ssh, api, certificate, etc.
                public_key TEXT,
                private_key TEXT,
                encrypted_private_key TEXT,
                passphrase_hash VARCHAR(255),
                metadata JSONB DEFAULT '{}',
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS service_accounts (
                id SERIAL PRIMARY KEY,
                username VARCHAR(255) NOT NULL UNIQUE,
                password_hash VARCHAR(255) NOT NULL,
                role VARCHAR(50) DEFAULT 'user',
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX IF NOT EXISTS idx_keypairs_type ON keypairs (type);
            CREATE INDEX IF NOT EXISTS idx_keypairs_name ON keypairs (name);
        `);
        console.log('✅ Database initialized');
    } catch (error) {
        console.error('❌ Database initialization failed:', error);
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
        const existing = await pool.query('SELECT id FROM keypairs WHERE name = $1', [name]);
        if (existing.rows.length > 0) {
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

        // Store in database
        const result = await pool.query(`
            INSERT INTO keypairs (name, type, public_key, private_key, encrypted_private_key, passphrase_hash, metadata)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id, name, type, created_at
        `, [
            name,
            'ssh',
            publicKey,
            passphrase ? null : privateKey, // Only store unencrypted if no passphrase
            encryptedPrivateKey,
            passphraseHash,
            { keySize, generated: true }
        ]);

        res.status(201).json({
            success: true,
            keypair: result.rows[0],
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
        const result = await pool.query(`
            SELECT id, name, type, metadata, created_at, updated_at
            FROM keypairs
            ORDER BY name
        `);

        res.json({
            success: true,
            keypairs: result.rows
        });
    } catch (error) {
        console.error('Error fetching keypairs:', error);
        res.status(500).json({ error: 'Failed to fetch keypairs' });
    }
});

// Get specific keypair
app.get('/api/keys/:id', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query(`
            SELECT id, name, type, public_key, metadata, created_at, updated_at
            FROM keypairs
            WHERE id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Keypair not found' });
        }

        res.json({
            success: true,
            keypair: result.rows[0]
        });
    } catch (error) {
        console.error('Error fetching keypair:', error);
        res.status(500).json({ error: 'Failed to fetch keypair' });
    }
});

// Get private key (requires passphrase if encrypted)
app.post('/api/keys/:id/private', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const { passphrase } = req.body;

        const result = await pool.query(`
            SELECT name, private_key, encrypted_private_key, passphrase_hash
            FROM keypairs
            WHERE id = $1
        `, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Keypair not found' });
        }

        const keypair = result.rows[0];

        let privateKey = keypair.private_key;

        // If private key is encrypted, require passphrase
        if (keypair.encrypted_private_key && !keypair.private_key) {
            if (!passphrase) {
                return res.status(400).json({ error: 'Passphrase required for encrypted key' });
            }

            // Verify passphrase
            const isValidPassphrase = await bcrypt.compare(passphrase, keypair.passphrase_hash);
            if (!isValidPassphrase) {
                return res.status(401).json({ error: 'Invalid passphrase' });
            }

            // Decrypt private key
            const decipher = crypto.createDecipher('aes-256-cbc', passphrase);
            privateKey = decipher.update(keypair.encrypted_private_key, 'hex', 'utf8') + decipher.final('utf8');
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
app.put('/api/keys/:id', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const { metadata } = req.body;

        const result = await pool.query(`
            UPDATE keypairs
            SET metadata = $1, updated_at = CURRENT_TIMESTAMP
            WHERE id = $2
            RETURNING id, name, type, metadata, updated_at
        `, [metadata || {}, id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Keypair not found' });
        }

        res.json({
            success: true,
            keypair: result.rows[0]
        });
    } catch (error) {
        console.error('Error updating keypair:', error);
        res.status(500).json({ error: 'Failed to update keypair' });
    }
});

// Delete keypair
app.delete('/api/keys/:id', authenticateToken, async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query('DELETE FROM keypairs WHERE id = $1 RETURNING name', [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Keypair not found' });
        }

        res.json({
            success: true,
            message: `Keypair '${result.rows[0].name}' deleted successfully`
        });
    } catch (error) {
    }
});

// Login endpoint
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Username and password required' });
        }

        // Check if user exists
        const result = await pool.query('SELECT * FROM service_accounts WHERE username = $1', [username]);
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const user = result.rows[0];

        // Verify password
        const isValidPassword = await bcrypt.compare(password, user.password_hash);
        if (!isValidPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Generate JWT token
        const token = jwt.sign(
            { id: user.id, username: user.username, role: user.role },
            process.env.JWT_SECRET || 'your-secret-key',
            { expiresIn: '24h' }
        );

        res.json({
            success: true,
            token: token,
            user: {
                id: user.id,
                username: user.username,
                role: user.role
            }
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Authentication failed' });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', service: 'keypair-service' });
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Unhandled error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// Start server
async function startServer() {
    await initDatabase();

    app.listen(port, () => {
        console.log(`🔑 Keypair Service listening on port ${port}`);
        console.log(`📊 Connected to PostgreSQL database`);
        console.log(`🔒 JWT Secret: ${process.env.JWT_SECRET ? 'configured' : 'using default'}`);
    });
}

startServer().catch(console.error);