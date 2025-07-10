#!/usr/bin/env node

/**
 * Claude Flow Core Integration
 * Main module that integrates all components
 */

import ClaudeFlowInitializer from './claude-flow-init.js';
import MemoryPersistence from './memory-persistence.js';
import AgentCoordinator from './agent-coordination.js';
import SessionManager from './session-manager.js';
import { readFile } from 'fs/promises';
import { existsSync } from 'fs';
import { join } from 'path';
import { EventEmitter } from 'events';

export class ClaudeFlowCore extends EventEmitter {
  constructor() {
    super();
    
    this.initialized = false;
    this.config = null;
    this.initializer = new ClaudeFlowInitializer();
    this.memory = null;
    this.coordinator = null;
    this.sessionManager = null;
    this.activeSwarmId = null;
  }

  /**
   * Initialize Claude Flow
   */
  async initialize() {
    if (this.initialized) {
      return { already_initialized: true };
    }

    try {
      console.log('🚀 Initializing Claude Flow Core...');
      
      // 1. Run initialization
      this.config = await this.initializer.initialize();
      
      // 2. Initialize memory persistence
      this.memory = new MemoryPersistence({
        basePath: this.config.memory.location,
        maxSize: this.parseSize(this.config.memory.maxSize),
        compression: this.config.memory.compression,
        encryption: this.config.memory.encryption
      });
      await this.memory.initialize();
      
      // 3. Initialize agent coordinator
      this.coordinator = new AgentCoordinator({
        topology: this.config.swarm.defaultTopology,
        maxAgents: this.config.swarm.maxAgents,
        strategies: this.config.swarm.strategies
      });
      
      // 4. Initialize session manager
      this.sessionManager = new SessionManager({
        sessionPath: join(this.config.memory.location, 'sessions'),
        autoSave: true
      });
      await this.sessionManager.initialize();
      
      // 5. Setup event listeners
      this.setupEventListeners();
      
      // 6. Create default session
      const session = await this.sessionManager.createSession({
        type: 'claude-flow',
        metadata: {
          version: this.config.version,
          features: this.config.features
        }
      });
      
      this.initialized = true;
      console.log('✅ Claude Flow Core initialized successfully!');
      
      return {
        initialized: true,
        sessionId: session.sessionId,
        version: this.config.version
      };
      
    } catch (error) {
      console.error('❌ Initialization failed:', error.message);
      throw error;
    }
  }

  /**
   * High-level API methods
   */

  async initSwarm(options = {}) {
    this.ensureInitialized();
    
    const result = await this.coordinator.initSwarm(options);
    this.activeSwarmId = result.swarmId;
    
    // Update session
    await this.sessionManager.addSwarm(result.swarmId, {
      topology: result.topology,
      maxAgents: result.maxAgents
    });
    
    // Store in memory
    await this.memory.store(`swarm:${result.swarmId}`, {
      ...result,
      created: Date.now()
    }, { namespace: 'swarms' });
    
    return result;
  }

  async spawnAgent(options = {}) {
    this.ensureInitialized();
    
    // Use active swarm if not specified
    if (!options.swarmId && this.activeSwarmId) {
      options.swarmId = this.activeSwarmId;
    }
    
    const result = await this.coordinator.spawnAgent(options);
    
    // Update session
    await this.sessionManager.addAgent(result.agentId, {
      type: result.type,
      name: result.name,
      swarmId: options.swarmId
    });
    
    // Store in memory
    await this.memory.store(`agent:${result.agentId}`, {
      ...result,
      created: Date.now()
    }, { namespace: 'agents' });
    
    return result;
  }

  async orchestrateTask(options = {}) {
    this.ensureInitialized();
    
    // Use active swarm if not specified
    if (!options.swarmId && this.activeSwarmId) {
      options.swarmId = this.activeSwarmId;
    }
    
    const result = await this.coordinator.orchestrateTask(options);
    
    // Update session
    await this.sessionManager.addTask(result.taskId, {
      description: options.task,
      strategy: options.strategy,
      swarmId: options.swarmId
    });
    
    // Store in memory
    await this.memory.store(`task:${result.taskId}`, {
      ...options,
      taskId: result.taskId,
      created: Date.now()
    }, { namespace: 'tasks' });
    
    return result;
  }

  async getSwarmStatus(swarmId) {
    this.ensureInitialized();
    
    swarmId = swarmId || this.activeSwarmId;
    if (!swarmId) {
      throw new Error('No active swarm');
    }
    
    return this.coordinator.getSwarmStatus(swarmId);
  }

  async getTaskStatus(taskId) {
    this.ensureInitialized();
    
    const task = this.coordinator.tasks.get(taskId);
    if (!task) {
      throw new Error(`Task ${taskId} not found`);
    }
    
    return {
      id: task.id,
      status: task.status,
      progress: task.subtasks.filter(st => st.completed).length / task.subtasks.length,
      created: task.created,
      started: task.started,
      completed: task.completed
    };
  }

  async destroySwarm(swarmId) {
    this.ensureInitialized();
    
    swarmId = swarmId || this.activeSwarmId;
    if (!swarmId) {
      throw new Error('No active swarm');
    }
    
    const result = await this.coordinator.destroySwarm(swarmId);
    
    if (swarmId === this.activeSwarmId) {
      this.activeSwarmId = null;
    }
    
    return result;
  }

  /**
   * Memory operations
   */

  async storeMemory(key, value, options = {}) {
    this.ensureInitialized();
    
    const result = await this.memory.store(key, value, options);
    
    // Update session memory
    await this.sessionManager.updateMemory(key, value);
    
    return result;
  }

  async retrieveMemory(key, namespace = 'default') {
    this.ensureInitialized();
    
    return this.memory.retrieve(key, namespace);
  }

  async searchMemory(pattern, options = {}) {
    this.ensureInitialized();
    
    return this.memory.search(pattern, options);
  }

  async listMemory(pattern = '*', namespace = 'default') {
    this.ensureInitialized();
    
    return this.memory.list(pattern, namespace);
  }

  /**
   * Session operations
   */

  async createCheckpoint(name, description) {
    this.ensureInitialized();
    
    return this.sessionManager.createCheckpoint(name, description);
  }

  async restoreCheckpoint(checkpointId) {
    this.ensureInitialized();
    
    return this.sessionManager.restoreCheckpoint(checkpointId);
  }

  async generateSummary() {
    this.ensureInitialized();
    
    return this.sessionManager.generateSummary();
  }

  async exportSession(format = 'json') {
    this.ensureInitialized();
    
    return this.sessionManager.exportSession(format);
  }

  async endSession() {
    this.ensureInitialized();
    
    const summary = await this.sessionManager.endSession();
    
    // Backup memory
    if (this.config.memory.persistent) {
      await this.memory.backup();
    }
    
    return summary;
  }

  /**
   * Utility methods
   */

  async getMetrics() {
    this.ensureInitialized();
    
    return {
      coordinator: this.coordinator.metrics,
      memory: {
        namespaces: Array.from(this.memory.namespaces.keys()),
        cacheSize: this.memory.cache.size
      },
      session: this.sessionManager.currentSession?.state.metrics
    };
  }

  async performanceReport(options = {}) {
    this.ensureInitialized();
    
    const metrics = await this.getMetrics();
    const summary = await this.sessionManager.generateSummary();
    
    return {
      metrics,
      summary,
      recommendations: this.generateRecommendations(metrics)
    };
  }

  /**
   * Helper methods
   */

  ensureInitialized() {
    if (!this.initialized) {
      throw new Error('Claude Flow not initialized. Call initialize() first.');
    }
  }

  parseSize(sizeStr) {
    const match = sizeStr.match(/^(\d+)(MB|GB|KB)?$/i);
    if (!match) return 100 * 1024 * 1024; // Default 100MB
    
    const size = parseInt(match[1]);
    const unit = (match[2] || 'MB').toUpperCase();
    
    switch (unit) {
      case 'KB': return size * 1024;
      case 'MB': return size * 1024 * 1024;
      case 'GB': return size * 1024 * 1024 * 1024;
      default: return size;
    }
  }

  setupEventListeners() {
    // Coordinator events
    this.coordinator.on('swarm:initialized', async (data) => {
      this.emit('swarm:initialized', data);
    });
    
    this.coordinator.on('agent:spawned', async (data) => {
      this.emit('agent:spawned', data);
    });
    
    this.coordinator.on('task:orchestrated', async (data) => {
      this.emit('task:orchestrated', data);
    });
    
    // Update metrics on task completion
    this.coordinator.on('task:completed', async (data) => {
      await this.sessionManager.updateMetrics({
        tasksCompleted: this.coordinator.metrics.tasksCompleted
      });
    });
  }

  generateRecommendations(metrics) {
    const recommendations = [];
    
    // Check coordinator metrics
    if (metrics.coordinator.avgCompletionTime > 10000) {
      recommendations.push({
        type: 'performance',
        message: 'Consider using parallel execution strategy for faster task completion'
      });
    }
    
    if (metrics.coordinator.tasksFailed > metrics.coordinator.tasksCompleted * 0.2) {
      recommendations.push({
        type: 'reliability',
        message: 'High failure rate detected. Review task complexity and agent capabilities'
      });
    }
    
    // Check memory usage
    if (metrics.memory.cacheSize > 1000) {
      recommendations.push({
        type: 'memory',
        message: 'Large cache size. Consider clearing old entries to improve performance'
      });
    }
    
    return recommendations;
  }

  /**
   * CLI Commands
   */

  async handleCommand(command, args = []) {
    switch (command) {
      case 'init':
        return this.initialize();
        
      case 'swarm':
        return this.handleSwarmCommand(args);
        
      case 'agent':
        return this.handleAgentCommand(args);
        
      case 'task':
        return this.handleTaskCommand(args);
        
      case 'memory':
        return this.handleMemoryCommand(args);
        
      case 'session':
        return this.handleSessionCommand(args);
        
      case 'status':
        return this.getSwarmStatus();
        
      case 'metrics':
        return this.getMetrics();
        
      case 'report':
        return this.performanceReport();
        
      default:
        throw new Error(`Unknown command: ${command}`);
    }
  }

  async handleSwarmCommand(args) {
    const subcommand = args[0];
    
    switch (subcommand) {
      case 'init':
        const topology = args[1] || 'hierarchical';
        return this.initSwarm({ topology });
        
      case 'status':
        return this.getSwarmStatus(args[1]);
        
      case 'destroy':
        return this.destroySwarm(args[1]);
        
      default:
        throw new Error(`Unknown swarm command: ${subcommand}`);
    }
  }

  async handleAgentCommand(args) {
    const subcommand = args[0];
    
    switch (subcommand) {
      case 'spawn':
        const type = args[1] || 'specialist';
        return this.spawnAgent({ type });
        
      case 'list':
        const swarmId = args[1] || this.activeSwarmId;
        const status = await this.getSwarmStatus(swarmId);
        return status.agents;
        
      default:
        throw new Error(`Unknown agent command: ${subcommand}`);
    }
  }

  async handleTaskCommand(args) {
    const subcommand = args[0];
    
    switch (subcommand) {
      case 'run':
        const task = args.slice(1).join(' ');
        return this.orchestrateTask({ task });
        
      case 'status':
        return this.getTaskStatus(args[1]);
        
      default:
        throw new Error(`Unknown task command: ${subcommand}`);
    }
  }

  async handleMemoryCommand(args) {
    const subcommand = args[0];
    
    switch (subcommand) {
      case 'store':
        return this.storeMemory(args[1], args[2]);
        
      case 'get':
        return this.retrieveMemory(args[1]);
        
      case 'search':
        return this.searchMemory(args[1]);
        
      case 'list':
        return this.listMemory(args[1]);
        
      default:
        throw new Error(`Unknown memory command: ${subcommand}`);
    }
  }

  async handleSessionCommand(args) {
    const subcommand = args[0];
    
    switch (subcommand) {
      case 'checkpoint':
        return this.createCheckpoint(args[1], args[2]);
        
      case 'restore':
        return this.restoreCheckpoint(args[1]);
        
      case 'summary':
        return this.generateSummary();
        
      case 'export':
        return this.exportSession(args[1]);
        
      case 'end':
        return this.endSession();
        
      default:
        throw new Error(`Unknown session command: ${subcommand}`);
    }
  }
}

// CLI Interface
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const core = new ClaudeFlowCore();
  
  const command = process.argv[2];
  const args = process.argv.slice(3);
  
  core.initialize()
    .then(() => core.handleCommand(command, args))
    .then(result => {
      console.log(JSON.stringify(result, null, 2));
      process.exit(0);
    })
    .catch(error => {
      console.error('Error:', error.message);
      process.exit(1);
    });
}

export default ClaudeFlowCore;