/**
 * Claude Flow Memory Persistence Layer
 * Handles persistent storage, retrieval, and management of memory across sessions
 */

import { readFile, writeFile, mkdir, readdir, unlink } from 'fs/promises';
import { existsSync } from 'fs';
import { join, resolve } from 'path';
import { gzipSync, gunzipSync } from 'zlib';
import crypto from 'crypto';

export class MemoryPersistence {
  constructor(config = {}) {
    this.basePath = config.basePath || './memory';
    this.maxSize = config.maxSize || 100 * 1024 * 1024; // 100MB default
    this.compression = config.compression !== false;
    this.encryption = config.encryption || false;
    this.encryptionKey = config.encryptionKey || null;
    this.namespaces = new Map();
    this.cache = new Map();
    this.ttlTimers = new Map();
  }

  async initialize() {
    // Ensure base directory exists
    if (!existsSync(this.basePath)) {
      await mkdir(this.basePath, { recursive: true });
    }

    // Load namespaces
    await this.loadNamespaces();
    
    // Initialize index
    await this.initializeIndex();
    
    // Start cleanup routine
    this.startCleanupRoutine();
  }

  async loadNamespaces() {
    const namespacePath = join(this.basePath, 'namespaces.json');
    
    if (existsSync(namespacePath)) {
      const data = await readFile(namespacePath, 'utf8');
      const namespaces = JSON.parse(data);
      
      for (const [name, config] of Object.entries(namespaces)) {
        this.namespaces.set(name, config);
      }
    } else {
      // Create default namespaces
      const defaults = {
        default: { maxSize: 50 * 1024 * 1024 },
        agents: { maxSize: 20 * 1024 * 1024 },
        tasks: { maxSize: 20 * 1024 * 1024 },
        sessions: { maxSize: 10 * 1024 * 1024 }
      };
      
      for (const [name, config] of Object.entries(defaults)) {
        this.namespaces.set(name, config);
        const nsPath = join(this.basePath, name);
        if (!existsSync(nsPath)) {
          await mkdir(nsPath, { recursive: true });
        }
      }
      
      await this.saveNamespaces();
    }
  }

  async saveNamespaces() {
    const namespacePath = join(this.basePath, 'namespaces.json');
    const data = Object.fromEntries(this.namespaces);
    await writeFile(namespacePath, JSON.stringify(data, null, 2), 'utf8');
  }

  async initializeIndex() {
    const indexPath = join(this.basePath, 'index', 'master.json');
    
    if (!existsSync(join(this.basePath, 'index'))) {
      await mkdir(join(this.basePath, 'index'), { recursive: true });
    }
    
    if (!existsSync(indexPath)) {
      const index = {
        version: 1,
        entries: {},
        created: Date.now(),
        lastUpdated: Date.now()
      };
      
      await writeFile(indexPath, JSON.stringify(index, null, 2), 'utf8');
    }
  }

  async store(key, value, options = {}) {
    const namespace = options.namespace || 'default';
    const ttl = options.ttl;
    const tags = options.tags || [];
    
    // Validate namespace
    if (!this.namespaces.has(namespace)) {
      throw new Error(`Namespace '${namespace}' does not exist`);
    }
    
    // Prepare data
    const entry = {
      key,
      value,
      namespace,
      tags,
      created: Date.now(),
      updated: Date.now(),
      expires: ttl ? Date.now() + ttl : null,
      size: JSON.stringify(value).length
    };
    
    // Check size limits
    const nsConfig = this.namespaces.get(namespace);
    if (entry.size > nsConfig.maxSize) {
      throw new Error(`Entry size exceeds namespace limit`);
    }
    
    // Store data
    const filePath = this.getFilePath(namespace, key);
    const fileData = this.compression ? 
      gzipSync(JSON.stringify(entry)) : 
      JSON.stringify(entry);
    
    // Encrypt if enabled
    const finalData = this.encryption && this.encryptionKey ? 
      this.encrypt(fileData) : 
      fileData;
    
    await writeFile(filePath, finalData);
    
    // Update index
    await this.updateIndex(namespace, key, entry);
    
    // Update cache
    this.cache.set(`${namespace}:${key}`, entry);
    
    // Set TTL timer if needed
    if (ttl) {
      this.setTTLTimer(namespace, key, ttl);
    }
    
    return { stored: true, size: entry.size };
  }

  async retrieve(key, namespace = 'default') {
    const cacheKey = `${namespace}:${key}`;
    
    // Check cache first
    if (this.cache.has(cacheKey)) {
      const cached = this.cache.get(cacheKey);
      if (!cached.expires || cached.expires > Date.now()) {
        return cached.value;
      }
    }
    
    // Load from disk
    const filePath = this.getFilePath(namespace, key);
    
    if (!existsSync(filePath)) {
      return null;
    }
    
    let fileData = await readFile(filePath);
    
    // Decrypt if needed
    if (this.encryption && this.encryptionKey) {
      fileData = this.decrypt(fileData);
    }
    
    // Decompress if needed
    const jsonData = this.compression ? 
      gunzipSync(fileData).toString() : 
      fileData.toString();
    
    const entry = JSON.parse(jsonData);
    
    // Check expiration
    if (entry.expires && entry.expires < Date.now()) {
      await this.delete(key, namespace);
      return null;
    }
    
    // Update cache
    this.cache.set(cacheKey, entry);
    
    return entry.value;
  }

  async list(pattern = '*', namespace = 'default') {
    const index = await this.loadIndex();
    const nsEntries = index.entries[namespace] || {};
    
    const regex = this.patternToRegex(pattern);
    const results = [];
    
    for (const [key, meta] of Object.entries(nsEntries)) {
      if (regex.test(key)) {
        // Check expiration
        if (!meta.expires || meta.expires > Date.now()) {
          results.push({
            key,
            namespace,
            created: meta.created,
            updated: meta.updated,
            size: meta.size,
            tags: meta.tags || []
          });
        }
      }
    }
    
    return results;
  }

  async delete(key, namespace = 'default') {
    const filePath = this.getFilePath(namespace, key);
    
    if (existsSync(filePath)) {
      await unlink(filePath);
    }
    
    // Remove from cache
    this.cache.delete(`${namespace}:${key}`);
    
    // Clear TTL timer
    const timerKey = `${namespace}:${key}`;
    if (this.ttlTimers.has(timerKey)) {
      clearTimeout(this.ttlTimers.get(timerKey));
      this.ttlTimers.delete(timerKey);
    }
    
    // Update index
    await this.removeFromIndex(namespace, key);
    
    return { deleted: true };
  }

  async search(query, options = {}) {
    const namespaces = options.namespaces || ['default'];
    const limit = options.limit || 100;
    const tags = options.tags || [];
    
    const results = [];
    
    for (const namespace of namespaces) {
      const entries = await this.list('*', namespace);
      
      for (const entry of entries) {
        // Tag filter
        if (tags.length > 0) {
          const hasAllTags = tags.every(tag => 
            entry.tags && entry.tags.includes(tag)
          );
          if (!hasAllTags) continue;
        }
        
        // Text search in key
        if (entry.key.toLowerCase().includes(query.toLowerCase())) {
          results.push(entry);
          
          if (results.length >= limit) {
            return results;
          }
        }
      }
    }
    
    return results;
  }

  async backup(backupPath) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupName = `backup-${timestamp}.json`;
    const fullBackupPath = join(backupPath || join(this.basePath, 'backups'), backupName);
    
    // Ensure backup directory exists
    const backupDir = resolve(fullBackupPath, '..');
    if (!existsSync(backupDir)) {
      await mkdir(backupDir, { recursive: true });
    }
    
    const backup = {
      version: 1,
      created: Date.now(),
      namespaces: Object.fromEntries(this.namespaces),
      data: {}
    };
    
    // Collect all data
    for (const [namespace] of this.namespaces) {
      backup.data[namespace] = {};
      const entries = await this.list('*', namespace);
      
      for (const entry of entries) {
        const value = await this.retrieve(entry.key, namespace);
        backup.data[namespace][entry.key] = {
          value,
          meta: entry
        };
      }
    }
    
    // Compress backup
    const backupData = this.compression ? 
      gzipSync(JSON.stringify(backup)) : 
      JSON.stringify(backup, null, 2);
    
    await writeFile(fullBackupPath, backupData);
    
    return { path: fullBackupPath, size: backupData.length };
  }

  async restore(backupPath) {
    if (!existsSync(backupPath)) {
      throw new Error(`Backup file not found: ${backupPath}`);
    }
    
    let backupData = await readFile(backupPath);
    
    // Decompress if needed
    try {
      backupData = gunzipSync(backupData);
    } catch {
      // Not compressed
    }
    
    const backup = JSON.parse(backupData.toString());
    
    // Restore namespaces
    this.namespaces = new Map(Object.entries(backup.namespaces));
    await this.saveNamespaces();
    
    // Restore data
    for (const [namespace, entries] of Object.entries(backup.data)) {
      for (const [key, data] of Object.entries(entries)) {
        await this.store(key, data.value, {
          namespace,
          tags: data.meta.tags
        });
      }
    }
    
    return { restored: true, namespaces: backup.namespaces };
  }

  // Helper methods
  getFilePath(namespace, key) {
    const safeKey = key.replace(/[^a-zA-Z0-9-_]/g, '_');
    const hash = crypto.createHash('md5').update(key).digest('hex');
    const subdir = hash.substring(0, 2);
    
    const dir = join(this.basePath, namespace, subdir);
    if (!existsSync(dir)) {
      mkdir(dir, { recursive: true });
    }
    
    return join(dir, `${safeKey}_${hash}.dat`);
  }

  patternToRegex(pattern) {
    const escaped = pattern
      .replace(/[.+?^${}()|[\]\\]/g, '\\$&')
      .replace(/\*/g, '.*')
      .replace(/\?/g, '.');
    return new RegExp(`^${escaped}$`);
  }

  async updateIndex(namespace, key, entry) {
    const index = await this.loadIndex();
    
    if (!index.entries[namespace]) {
      index.entries[namespace] = {};
    }
    
    index.entries[namespace][key] = {
      created: entry.created,
      updated: entry.updated,
      expires: entry.expires,
      size: entry.size,
      tags: entry.tags
    };
    
    index.lastUpdated = Date.now();
    
    await this.saveIndex(index);
  }

  async removeFromIndex(namespace, key) {
    const index = await this.loadIndex();
    
    if (index.entries[namespace] && index.entries[namespace][key]) {
      delete index.entries[namespace][key];
      index.lastUpdated = Date.now();
      await this.saveIndex(index);
    }
  }

  async loadIndex() {
    const indexPath = join(this.basePath, 'index', 'master.json');
    const data = await readFile(indexPath, 'utf8');
    return JSON.parse(data);
  }

  async saveIndex(index) {
    const indexPath = join(this.basePath, 'index', 'master.json');
    await writeFile(indexPath, JSON.stringify(index, null, 2), 'utf8');
  }

  setTTLTimer(namespace, key, ttl) {
    const timerKey = `${namespace}:${key}`;
    
    // Clear existing timer
    if (this.ttlTimers.has(timerKey)) {
      clearTimeout(this.ttlTimers.get(timerKey));
    }
    
    // Set new timer
    const timer = setTimeout(async () => {
      await this.delete(key, namespace);
      this.ttlTimers.delete(timerKey);
    }, ttl);
    
    this.ttlTimers.set(timerKey, timer);
  }

  startCleanupRoutine() {
    // Run cleanup every hour
    setInterval(async () => {
      const index = await this.loadIndex();
      const now = Date.now();
      
      for (const [namespace, entries] of Object.entries(index.entries)) {
        for (const [key, meta] of Object.entries(entries)) {
          if (meta.expires && meta.expires < now) {
            await this.delete(key, namespace);
          }
        }
      }
    }, 60 * 60 * 1000);
  }

  encrypt(data) {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv(
      'aes-256-cbc',
      Buffer.from(this.encryptionKey, 'hex'),
      iv
    );
    
    let encrypted = cipher.update(data);
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    
    return Buffer.concat([iv, encrypted]);
  }

  decrypt(data) {
    const iv = data.slice(0, 16);
    const encrypted = data.slice(16);
    
    const decipher = crypto.createDecipheriv(
      'aes-256-cbc',
      Buffer.from(this.encryptionKey, 'hex'),
      iv
    );
    
    let decrypted = decipher.update(encrypted);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    
    return decrypted;
  }
}

export default MemoryPersistence;