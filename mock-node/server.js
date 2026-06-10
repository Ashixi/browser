const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;
const STORAGE_DIR = path.join(__dirname, 'data_chunks');

// Ensure storage directory exists
if (!fs.existsSync(STORAGE_DIR)) {
    fs.mkdirSync(STORAGE_DIR, { recursive: true });
}

// Multer setup for handling multipart/form-data
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, STORAGE_DIR);
    },
    filename: function (req, file, cb) {
        // Use provided id in body/query or generate a new one
        const id = req.body.id || req.query.id || uuidv4();
        cb(null, id);
    }
});

const upload = multer({ storage: storage });

// Middleware for parsing raw binary data if not using multipart
app.use(express.raw({ type: '*/*', limit: '500mb' }));

// Middleware для підтримки CORS
app.use((req, res, next) => {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, x-chunk-id");
    res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    if (req.method === "OPTIONS") {
        return res.sendStatus(200);
    }
    next();
});

// POST /storage/chunk
// Accepts chunk and saves locally
app.post('/storage/chunk', upload.single('chunk'), (req, res) => {
    try {
        let chunkId;

        if (req.file) {
            // Handled by multer (multipart/form-data)
            chunkId = req.file.filename;
        } else if (req.body && Buffer.isBuffer(req.body) && req.body.length > 0) {
            // Handled as raw body
            chunkId = req.query.id || req.headers['x-chunk-id'] || uuidv4();
            const filePath = path.join(STORAGE_DIR, chunkId);
            fs.writeFileSync(filePath, req.body);
        } else {
            return res.status(400).json({ error: 'No chunk data provided' });
        }

        res.status(200).json({
            message: 'Chunk saved successfully',
            id: chunkId
        });
    } catch (error) {
        console.error('Error saving chunk:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// GET /storage/chunk/{id}
// Finds and returns the chunk by its ID
app.get('/storage/chunk/:id', (req, res) => {
    const chunkId = req.params.id;
    const filePath = path.join(STORAGE_DIR, chunkId);

    if (fs.existsSync(filePath)) {
        res.sendFile(filePath);
    } else {
        res.status(404).json({ error: 'Chunk not found' });
    }
});

const FEEDO_NODE_URL = process.env.FEEDO_NODE_URL || 'http://localhost:4000'; 

app.get('/page/:hash_id', async (req, res) => {
    const { hash_id } = req.params;

    if (!hash_id) {
        return res.status(400).json({ error: 'Missing hash_id parameter' });
    }

    try {
        console.log(`[Proxy] Requesting content for hash: ${hash_id} from Feedo node...`);
        
        const feedoResponse = await fetch(`${FEEDO_NODE_URL}/content/${hash_id}`);
        
        if (!feedoResponse.ok) {
            console.error(`[Proxy] Feedo node responded with status: ${feedoResponse.status}`);
            return res.status(feedoResponse.status).json({ 
                error: `Failed to fetch content from Feedo node: ${feedoResponse.statusText}` 
            });
        }

        const arrayBuffer = await feedoResponse.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        const contentType = feedoResponse.headers.get('content-type') || 'application/octet-stream';
        res.setHeader('Content-Type', contentType);

        res.send(buffer);

    } catch (error) {
        console.error('[Proxy] Error connecting to Feedo node:', error);
        res.status(500).json({ error: 'Internal server error or Feedo node is unreachable' });
    }
});

app.listen(PORT, () => {
    console.log(`Mock storage node is running on http://localhost:${PORT}`);
    console.log(`Chunks will be stored in: ${STORAGE_DIR}`);
});

const crypto = require('crypto');

// Конфігурація адреси ноди для публікації контенту
const PUBLISH_NODE_URL = process.env.PUBLISH_NODE_URL || 'http://localhost:4000';

// Ініціалізація локальних ключів користувача (імітація гаманця/ідентифікатора)
// Для реальних P2P систем часто використовують Ed25519 (швидкий та безпечний)
let privateKey, publicKey;

function initKeyPair() {
    // Генеруємо пару ключів, якщо вони потрібні для сесії
    // У реальному браузері вони б завантажувалися з захищеного сховища
    const pair = crypto.generateKeyPairSync('ed25519', {
        privateKeyEncoding: { format: 'pem', type: 'pkcs8' },
        publicKeyEncoding: { format: 'pem', type: 'spki' }
    });
    privateKey = pair.privateKey;
    publicKey = pair.publicKey;
    console.log('[Crypto] Local KeyPair initialized successfully.');
}
initKeyPair();

// POST /content/publish
// Приймає контент від фронтенду, формує корисне навантаження, підписує його та відправляє на ноду
app.post('/content/publish', async (req, res) => {
    let data;

    // Якщо дані прийшли як JSON-рядок через raw-парсер
    if (req.body && Buffer.isBuffer(req.body)) {
        try {
            const parsedBody = JSON.parse(req.body.toString());
            data = parsedBody.data;
        } catch (e) {
            // Якщо це не JSON, а звичайний текст
            data = req.body.toString();
        }
    } else {
        data = req.body?.data;
    }

    if (!data) {
        return res.status(400).json({ error: 'No data provided for publication' });
    }

    try {
        // 1. Формуємо корисне навантаження (Payload)
        const payload = {
            content: data,
            timestamp: Date.now(),
            author: publicKey.replace(/[\n\r]/g, '')
        };

        const payloadString = JSON.stringify(payload);

        // 2. Підписуємо навантаження локальним приватним ключем
        const signature = crypto.sign(null, Buffer.from(payloadString), privateKey);
        
        // 3. Формуємо фінальний пакет
        const signedPacket = {
            payload: payload,
            signature: signature.toString('hex')
        };

        console.log('[Crypto] Payload signed successfully. Sending to decentralized node...');

        // 4. Відправляємо підписаний пакет на децентралізовану ноду
        const nodeResponse = await fetch(`${PUBLISH_NODE_URL}/content/publish`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(signedPacket)
        });

        if (!nodeResponse.ok) {
            console.error(`[Node Error] Main node responded with status: ${nodeResponse.status}`);
            return res.status(nodeResponse.status).json({
                error: `Node failed to publish content: ${nodeResponse.statusText}`
            });
        }

        const nodeResult = await nodeResponse.json();

        res.status(200).json({
            message: 'Content signed and published successfully',
            author: payload.author,
            signature: signedPacket.signature,
            nodeResponse: nodeResult
        });

    } catch (error) {
        console.error('[Publish Error] Error processing content publication:', error);
        res.status(500).json({ error: 'Internal server error or destination node is unreachable' });
    }
});