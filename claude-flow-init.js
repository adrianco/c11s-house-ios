#!/usr/bin/env node

/**
 * Claude Flow Core Initialization Module
 * Handles system initialization, configuration, and bootstrap
 */

import { readFile, writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import { join, resolve } from 'path';
import { fileURLToPath } from 'url';
import { homedir } from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname = resolve(__filename, '..');

// Default configuration
const DEFAULT_CONFIG = {
  version: '2.0.0-alpha.27',
  memory: {
    persistent: true,
    location: './memory',
    maxSize: '100MB',
    ttl: 86400000, // 24 hours
    namespaces: ['default', 'agents', 'tasks', 'sessions']
  },
  swarm: {
    defaultTopology: 'hierarchical',
    maxAgents: 8,
    strategies: ['parallel', 'sequential', 'adaptive', 'balanced'],
    autoSpawn: true
  },
  neural: {
    enabled: true,
    wasmOptimized: true,
    modelPath: './models',
    trainingEnabled: true
  },
  hooks: {
    enabled: true,
    autoFormat: true,
    autoCommit: false,
    telemetry: true
  },
  performance: {
    monitoring: true,
    bottleneckAnalysis: true,
    tokenOptimization: true,
    caching: true
  },
  github: {
    enabled: false,
    token: null,
    webhooks: false
  }
};

class ClaudeFlowInitializer {
  constructor() {
    this.configPath = join(process.cwd(), '.claude', 'claude-flow.json');
    this.memoryPath = join(process.cwd(), 'memory');
    this.globalConfigPath = join(homedir(), '.claude-flow', 'config.json');
  }

  async initialize() {
    console.log('🚀 Initializing Claude Flow...');
    
    try {
      // 1. Setup directory structure
      await this.setupDirectories();
      
      // 2. Load or create configuration
      const config = await this.loadConfiguration();
      
      // 3. Initialize memory system
      await this.initializeMemory(config);
      
      // 4. Setup agent coordination
      await this.setupAgentCoordination(config);
      
      // 5. Initialize neural patterns
      await this.initializeNeuralPatterns(config);
      
      // 6. Setup hooks
      await this.setupHooks(config);
      
      // 7. Verify installation
      await this.verifyInstallation();
      
      console.log('✅ Claude Flow initialized successfully!');
      return config;
      
    } catch (error) {
      console.error('❌ Initialization failed:', error.message);
      throw error;
    }
  }

  async setupDirectories() {
    const dirs = [
      '.claude',
      '.claude/commands',
      '.claude/hooks',
      '.claude/templates',
      'memory',
      'memory/agents',
      'memory/sessions',
      'memory/backups',
      'memory/data',
      'memory/index',
      'coordination',
      'coordination/memory_bank',
      'coordination/orchestration',
      'coordination/subtasks',
      'models',
      'models/neural',
      'models/trained'
    ];

    for (const dir of dirs) {
      const path = join(process.cwd(), dir);
      if (!existsSync(path)) {
        await mkdir(path, { recursive: true });
      }
    }
  }

  async loadConfiguration() {
    // Try to load existing config
    if (existsSync(this.configPath)) {
      const content = await readFile(this.configPath, 'utf8');
      return { ...DEFAULT_CONFIG, ...JSON.parse(content) };
    }

    // Create new config
    await this.saveConfiguration(DEFAULT_CONFIG);
    return DEFAULT_CONFIG;
  }

  async saveConfiguration(config) {
    const configDir = join(process.cwd(), '.claude');
    if (!existsSync(configDir)) {
      await mkdir(configDir, { recursive: true });
    }
    
    await writeFile(
      this.configPath,
      JSON.stringify(config, null, 2),
      'utf8'
    );
  }

  async initializeMemory(config) {
    const memoryDataPath = join(this.memoryPath, 'claude-flow-data.json');
    
    if (!existsSync(memoryDataPath)) {
      const initialData = {
        agents: [],
        tasks: [],
        sessions: {},
        neural: {
          patterns: [],
          models: []
        },
        lastUpdated: Date.now()
      };
      
      await writeFile(
        memoryDataPath,
        JSON.stringify(initialData, null, 2),
        'utf8'
      );
    }

    // Create namespace directories
    for (const namespace of config.memory.namespaces) {
      const nsPath = join(this.memoryPath, namespace);
      if (!existsSync(nsPath)) {
        await mkdir(nsPath, { recursive: true });
      }
    }
  }

  async setupAgentCoordination(config) {
    const coordinationConfig = {
      topology: config.swarm.defaultTopology,
      maxAgents: config.swarm.maxAgents,
      strategies: config.swarm.strategies,
      autoSpawn: config.swarm.autoSpawn,
      coordination: {
        messageQueue: [],
        taskQueue: [],
        agentRegistry: {},
        locks: {}
      }
    };

    const coordPath = join(process.cwd(), 'coordination', 'config.json');
    await writeFile(
      coordPath,
      JSON.stringify(coordinationConfig, null, 2),
      'utf8'
    );
  }

  async initializeNeuralPatterns(config) {
    if (!config.neural.enabled) return;

    const neuralConfig = {
      wasmOptimized: config.neural.wasmOptimized,
      models: [],
      patterns: {
        coordination: [],
        optimization: [],
        prediction: []
      },
      training: {
        enabled: config.neural.trainingEnabled,
        epochs: 50,
        batchSize: 32
      }
    };

    const neuralPath = join(process.cwd(), 'models', 'neural', 'config.json');
    if (!existsSync(neuralPath)) {
      await writeFile(
        neuralPath,
        JSON.stringify(neuralConfig, null, 2),
        'utf8'
      );
    }
  }

  async setupHooks(config) {
    if (!config.hooks.enabled) return;

    const hooksConfig = {
      preTask: {
        enabled: true,
        actions: ['loadContext', 'validateResources', 'optimizeTopology']
      },
      postEdit: {
        enabled: config.hooks.autoFormat,
        actions: ['format', 'lint', 'updateMemory']
      },
      sessionEnd: {
        enabled: true,
        actions: ['saveState', 'generateSummary', 'trainPatterns']
      },
      notification: {
        enabled: config.hooks.telemetry,
        actions: ['logTelemetry', 'updateMetrics']
      }
    };

    const hooksPath = join(process.cwd(), '.claude', 'hooks', 'config.json');
    await writeFile(
      hooksPath,
      JSON.stringify(hooksConfig, null, 2),
      'utf8'
    );
  }

  async verifyInstallation() {
    const requiredFiles = [
      this.configPath,
      join(this.memoryPath, 'claude-flow-data.json'),
      join(process.cwd(), 'coordination', 'config.json')
    ];

    for (const file of requiredFiles) {
      if (!existsSync(file)) {
        throw new Error(`Required file missing: ${file}`);
      }
    }
  }

  async reset() {
    console.log('🔄 Resetting Claude Flow configuration...');
    
    // Remove configuration
    if (existsSync(this.configPath)) {
      const { unlink } = await import('fs/promises');
      await unlink(this.configPath);
    }
    
    // Re-initialize
    return this.initialize();
  }
}

// CLI Interface
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const initializer = new ClaudeFlowInitializer();
  
  const command = process.argv[2];
  
  switch (command) {
    case 'reset':
      initializer.reset().catch(console.error);
      break;
    case 'verify':
      initializer.verifyInstallation()
        .then(() => console.log('✅ Installation verified'))
        .catch(err => console.error('❌ Verification failed:', err.message));
      break;
    default:
      initializer.initialize().catch(console.error);
  }
}

export default ClaudeFlowInitializer;