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

app.listen(PORT, () => {
    console.log(`Mock storage node is running on http://localhost:${PORT}`);
    console.log(`Chunks will be stored in: ${STORAGE_DIR}`);
});
