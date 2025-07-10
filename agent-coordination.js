/**
 * Claude Flow Agent Coordination Logic
 * Manages swarm coordination, task distribution, and agent lifecycle
 */

import { EventEmitter } from 'events';
import { randomUUID } from 'crypto';
import { performance } from 'perf_hooks';

export class AgentCoordinator extends EventEmitter {
  constructor(config = {}) {
    super();
    
    this.swarms = new Map();
    this.agents = new Map();
    this.tasks = new Map();
    this.topology = config.topology || 'hierarchical';
    this.maxAgents = config.maxAgents || 8;
    this.strategies = config.strategies || ['parallel', 'sequential', 'adaptive', 'balanced'];
    this.messageQueue = [];
    this.coordinationLocks = new Map();
    this.metrics = {
      tasksCompleted: 0,
      tasksInProgress: 0,
      tasksFailed: 0,
      avgCompletionTime: 0,
      tokenUsage: 0
    };
  }

  /**
   * Initialize a new swarm with specified topology
   */
  async initSwarm(options = {}) {
    const swarmId = options.swarmId || randomUUID();
    const topology = options.topology || this.topology;
    const maxAgents = options.maxAgents || this.maxAgents;
    const strategy = options.strategy || 'auto';

    const swarm = {
      id: swarmId,
      topology,
      maxAgents,
      strategy,
      agents: new Set(),
      tasks: new Set(),
      status: 'active',
      created: Date.now(),
      metrics: {
        efficiency: 1.0,
        load: 0,
        throughput: 0
      }
    };

    this.swarms.set(swarmId, swarm);
    
    // Setup topology-specific coordination
    await this.setupTopology(swarmId, topology);
    
    this.emit('swarm:initialized', { swarmId, topology });
    
    return { swarmId, topology, maxAgents };
  }

  /**
   * Spawn a specialized agent
   */
  async spawnAgent(options = {}) {
    const agentId = options.agentId || randomUUID();
    const type = options.type || 'specialist';
    const name = options.name || `${type}-${agentId.slice(0, 8)}`;
    const swarmId = options.swarmId || this.getActiveSwarmId();
    const capabilities = options.capabilities || this.getDefaultCapabilities(type);

    const agent = {
      id: agentId,
      type,
      name,
      swarmId,
      capabilities,
      status: 'idle',
      created: Date.now(),
      lastActive: Date.now(),
      tasksCompleted: 0,
      currentTask: null,
      memory: new Map(),
      performance: {
        avgTaskTime: 0,
        successRate: 1.0,
        specialization: this.calculateSpecialization(type)
      }
    };

    this.agents.set(agentId, agent);
    
    // Add to swarm
    if (swarmId && this.swarms.has(swarmId)) {
      const swarm = this.swarms.get(swarmId);
      swarm.agents.add(agentId);
      
      // Rebalance if needed
      if (swarm.agents.size > swarm.maxAgents) {
        await this.rebalanceSwarm(swarmId);
      }
    }
    
    this.emit('agent:spawned', { agentId, type, name, swarmId });
    
    return { agentId, type, name, capabilities };
  }

  /**
   * Orchestrate a complex task
   */
  async orchestrateTask(options = {}) {
    const taskId = options.taskId || randomUUID();
    const task = options.task || '';
    const strategy = options.strategy || 'adaptive';
    const priority = options.priority || 'medium';
    const dependencies = options.dependencies || [];
    const swarmId = options.swarmId || this.getActiveSwarmId();

    const taskObj = {
      id: taskId,
      description: task,
      strategy,
      priority,
      dependencies,
      swarmId,
      status: 'pending',
      created: Date.now(),
      started: null,
      completed: null,
      subtasks: [],
      assignedAgents: new Set(),
      results: null,
      error: null
    };

    this.tasks.set(taskId, taskObj);
    
    // Add to swarm
    if (swarmId && this.swarms.has(swarmId)) {
      this.swarms.get(swarmId).tasks.add(taskId);
    }
    
    // Decompose task
    const subtasks = await this.decomposeTask(taskObj);
    taskObj.subtasks = subtasks;
    
    // Execute based on strategy
    switch (strategy) {
      case 'parallel':
        await this.executeParallel(taskObj);
        break;
      case 'sequential':
        await this.executeSequential(taskObj);
        break;
      case 'adaptive':
        await this.executeAdaptive(taskObj);
        break;
      case 'balanced':
        await this.executeBalanced(taskObj);
        break;
      default:
        await this.executeAuto(taskObj);
    }
    
    this.emit('task:orchestrated', { taskId, strategy });
    
    return { taskId, status: 'orchestrating' };
  }

  /**
   * Setup topology-specific coordination
   */
  async setupTopology(swarmId, topology) {
    const swarm = this.swarms.get(swarmId);
    
    switch (topology) {
      case 'hierarchical':
        swarm.structure = {
          type: 'hierarchical',
          levels: 3,
          root: null,
          branches: new Map()
        };
        break;
        
      case 'mesh':
        swarm.structure = {
          type: 'mesh',
          connections: new Map(),
          minConnections: 3
        };
        break;
        
      case 'ring':
        swarm.structure = {
          type: 'ring',
          order: [],
          bidirectional: true
        };
        break;
        
      case 'star':
        swarm.structure = {
          type: 'star',
          center: null,
          spokes: new Set()
        };
        break;
    }
  }

  /**
   * Decompose task into subtasks
   */
  async decomposeTask(task) {
    const subtasks = [];
    const complexity = this.analyzeComplexity(task.description);
    
    // Basic decomposition based on task keywords
    const components = this.extractComponents(task.description);
    
    for (const component of components) {
      subtasks.push({
        id: randomUUID(),
        parentId: task.id,
        description: component.description,
        type: component.type,
        priority: component.priority || task.priority,
        dependencies: component.dependencies || [],
        estimatedTime: component.estimatedTime || complexity * 1000,
        requiredCapabilities: component.capabilities || []
      });
    }
    
    return subtasks;
  }

  /**
   * Execute tasks in parallel
   */
  async executeParallel(task) {
    task.status = 'in_progress';
    task.started = Date.now();
    
    const availableAgents = await this.getAvailableAgents(task.swarmId);
    const assignments = new Map();
    
    // Assign subtasks to agents
    for (const subtask of task.subtasks) {
      const agent = this.findBestAgent(availableAgents, subtask);
      if (agent) {
        assignments.set(subtask.id, agent.id);
        agent.status = 'busy';
        agent.currentTask = subtask.id;
        task.assignedAgents.add(agent.id);
      }
    }
    
    // Execute all subtasks in parallel
    const promises = [];
    for (const [subtaskId, agentId] of assignments) {
      const subtask = task.subtasks.find(st => st.id === subtaskId);
      const agent = this.agents.get(agentId);
      promises.push(this.executeSubtask(agent, subtask));
    }
    
    // Wait for all to complete
    const results = await Promise.allSettled(promises);
    
    // Collect results
    task.results = results.map((result, index) => ({
      subtaskId: task.subtasks[index].id,
      status: result.status,
      value: result.value || result.reason
    }));
    
    task.status = 'completed';
    task.completed = Date.now();
    
    this.metrics.tasksCompleted++;
    this.updateMetrics(task);
  }

  /**
   * Execute tasks sequentially
   */
  async executeSequential(task) {
    task.status = 'in_progress';
    task.started = Date.now();
    
    const results = [];
    
    for (const subtask of task.subtasks) {
      const availableAgents = await this.getAvailableAgents(task.swarmId);
      const agent = this.findBestAgent(availableAgents, subtask);
      
      if (agent) {
        agent.status = 'busy';
        agent.currentTask = subtask.id;
        task.assignedAgents.add(agent.id);
        
        try {
          const result = await this.executeSubtask(agent, subtask);
          results.push({
            subtaskId: subtask.id,
            status: 'fulfilled',
            value: result
          });
        } catch (error) {
          results.push({
            subtaskId: subtask.id,
            status: 'rejected',
            value: error.message
          });
        }
        
        agent.status = 'idle';
        agent.currentTask = null;
      }
    }
    
    task.results = results;
    task.status = 'completed';
    task.completed = Date.now();
    
    this.metrics.tasksCompleted++;
    this.updateMetrics(task);
  }

  /**
   * Execute tasks adaptively
   */
  async executeAdaptive(task) {
    // Analyze task characteristics
    const analysis = await this.analyzeTask(task);
    
    // Choose strategy based on analysis
    if (analysis.parallelizable > 0.7) {
      await this.executeParallel(task);
    } else if (analysis.dependencies > 0.5) {
      await this.executeSequential(task);
    } else {
      await this.executeBalanced(task);
    }
  }

  /**
   * Execute tasks with balanced approach
   */
  async executeBalanced(task) {
    task.status = 'in_progress';
    task.started = Date.now();
    
    // Group subtasks by dependencies
    const groups = this.groupByDependencies(task.subtasks);
    const results = [];
    
    // Execute each group
    for (const group of groups) {
      const groupPromises = [];
      
      for (const subtask of group) {
        const availableAgents = await this.getAvailableAgents(task.swarmId);
        const agent = this.findBestAgent(availableAgents, subtask);
        
        if (agent) {
          agent.status = 'busy';
          agent.currentTask = subtask.id;
          task.assignedAgents.add(agent.id);
          
          groupPromises.push(
            this.executeSubtask(agent, subtask)
              .then(result => {
                agent.status = 'idle';
                agent.currentTask = null;
                return { subtaskId: subtask.id, status: 'fulfilled', value: result };
              })
              .catch(error => {
                agent.status = 'idle';
                agent.currentTask = null;
                return { subtaskId: subtask.id, status: 'rejected', value: error.message };
              })
          );
        }
      }
      
      const groupResults = await Promise.allSettled(groupPromises);
      results.push(...groupResults.map(r => r.value));
    }
    
    task.results = results;
    task.status = 'completed';
    task.completed = Date.now();
    
    this.metrics.tasksCompleted++;
    this.updateMetrics(task);
  }

  /**
   * Execute with automatic strategy selection
   */
  async executeAuto(task) {
    const swarm = this.swarms.get(task.swarmId);
    
    // Select strategy based on swarm metrics
    if (swarm.metrics.load < 0.3) {
      await this.executeParallel(task);
    } else if (swarm.metrics.load > 0.7) {
      await this.executeSequential(task);
    } else {
      await this.executeBalanced(task);
    }
  }

  /**
   * Execute a single subtask
   */
  async executeSubtask(agent, subtask) {
    const startTime = performance.now();
    
    try {
      // Simulate task execution
      await this.simulateWork(subtask.estimatedTime);
      
      // Update agent stats
      agent.tasksCompleted++;
      agent.lastActive = Date.now();
      
      const duration = performance.now() - startTime;
      this.updateAgentPerformance(agent, duration, true);
      
      return {
        agentId: agent.id,
        subtaskId: subtask.id,
        duration,
        result: `Completed by ${agent.name}`
      };
      
    } catch (error) {
      const duration = performance.now() - startTime;
      this.updateAgentPerformance(agent, duration, false);
      throw error;
    }
  }

  /**
   * Helper methods
   */
  
  getActiveSwarmId() {
    for (const [id, swarm] of this.swarms) {
      if (swarm.status === 'active') {
        return id;
      }
    }
    return null;
  }

  getDefaultCapabilities(type) {
    const capabilities = {
      coordinator: ['planning', 'orchestration', 'monitoring'],
      researcher: ['search', 'analysis', 'documentation'],
      coder: ['implementation', 'debugging', 'refactoring'],
      analyst: ['data-analysis', 'optimization', 'reporting'],
      architect: ['design', 'patterns', 'structure'],
      tester: ['testing', 'validation', 'quality'],
      reviewer: ['review', 'feedback', 'approval'],
      optimizer: ['performance', 'efficiency', 'scaling'],
      documenter: ['documentation', 'examples', 'guides'],
      monitor: ['monitoring', 'alerting', 'metrics'],
      specialist: ['domain-specific', 'custom', 'flexible']
    };
    
    return capabilities[type] || capabilities.specialist;
  }

  calculateSpecialization(type) {
    const specializations = {
      coordinator: { leadership: 0.9, technical: 0.5 },
      researcher: { analysis: 0.9, exploration: 0.8 },
      coder: { implementation: 0.9, problem_solving: 0.8 },
      analyst: { data_processing: 0.9, insights: 0.8 },
      architect: { design: 0.9, abstraction: 0.9 },
      tester: { validation: 0.9, edge_cases: 0.8 },
      reviewer: { critique: 0.8, standards: 0.9 },
      optimizer: { efficiency: 0.9, performance: 0.9 },
      documenter: { clarity: 0.9, completeness: 0.8 },
      monitor: { observability: 0.9, alerting: 0.8 },
      specialist: { adaptability: 0.8, learning: 0.7 }
    };
    
    return specializations[type] || specializations.specialist;
  }

  async getAvailableAgents(swarmId) {
    const agents = [];
    
    for (const [id, agent] of this.agents) {
      if (agent.swarmId === swarmId && agent.status === 'idle') {
        agents.push(agent);
      }
    }
    
    return agents;
  }

  findBestAgent(agents, subtask) {
    let bestAgent = null;
    let bestScore = -1;
    
    for (const agent of agents) {
      const score = this.calculateAgentScore(agent, subtask);
      if (score > bestScore) {
        bestScore = score;
        bestAgent = agent;
      }
    }
    
    return bestAgent;
  }

  calculateAgentScore(agent, subtask) {
    let score = 0;
    
    // Check capability match
    for (const required of subtask.requiredCapabilities) {
      if (agent.capabilities.includes(required)) {
        score += 0.2;
      }
    }
    
    // Factor in performance
    score += agent.performance.successRate * 0.3;
    score += (1 - agent.performance.avgTaskTime / 10000) * 0.2;
    
    // Type-specific bonuses
    if (subtask.type && agent.type === subtask.type) {
      score += 0.3;
    }
    
    return score;
  }

  analyzeComplexity(description) {
    // Simple complexity analysis based on keywords
    const complexKeywords = ['complex', 'advanced', 'sophisticated', 'comprehensive'];
    const simpleKeywords = ['simple', 'basic', 'straightforward', 'easy'];
    
    let complexity = 5; // Default medium complexity
    
    for (const keyword of complexKeywords) {
      if (description.toLowerCase().includes(keyword)) {
        complexity += 2;
      }
    }
    
    for (const keyword of simpleKeywords) {
      if (description.toLowerCase().includes(keyword)) {
        complexity -= 2;
      }
    }
    
    return Math.max(1, Math.min(10, complexity));
  }

  extractComponents(description) {
    // Basic component extraction
    const components = [];
    
    // Look for common patterns
    const patterns = [
      { regex: /implement\s+(\w+)/gi, type: 'implementation' },
      { regex: /test\s+(\w+)/gi, type: 'testing' },
      { regex: /design\s+(\w+)/gi, type: 'design' },
      { regex: /analyze\s+(\w+)/gi, type: 'analysis' },
      { regex: /optimize\s+(\w+)/gi, type: 'optimization' }
    ];
    
    for (const pattern of patterns) {
      const matches = description.matchAll(pattern.regex);
      for (const match of matches) {
        components.push({
          description: match[0],
          type: pattern.type,
          capabilities: [pattern.type]
        });
      }
    }
    
    // If no specific components found, create a generic one
    if (components.length === 0) {
      components.push({
        description: description,
        type: 'general',
        capabilities: ['domain-specific']
      });
    }
    
    return components;
  }

  async analyzeTask(task) {
    const subtaskCount = task.subtasks.length;
    const dependencyCount = task.subtasks.reduce((sum, st) => sum + st.dependencies.length, 0);
    
    return {
      parallelizable: subtaskCount > 1 && dependencyCount === 0 ? 1.0 : 0.5,
      dependencies: dependencyCount / Math.max(1, subtaskCount),
      complexity: this.analyzeComplexity(task.description) / 10
    };
  }

  groupByDependencies(subtasks) {
    const groups = [];
    const processed = new Set();
    
    while (processed.size < subtasks.length) {
      const group = [];
      
      for (const subtask of subtasks) {
        if (!processed.has(subtask.id)) {
          // Check if all dependencies are processed
          const canProcess = subtask.dependencies.every(dep => processed.has(dep));
          
          if (canProcess) {
            group.push(subtask);
            processed.add(subtask.id);
          }
        }
      }
      
      if (group.length > 0) {
        groups.push(group);
      }
    }
    
    return groups;
  }

  async simulateWork(duration) {
    // Simulate work with random variation
    const actualDuration = duration * (0.8 + Math.random() * 0.4);
    await new Promise(resolve => setTimeout(resolve, actualDuration));
  }

  updateAgentPerformance(agent, duration, success) {
    const perf = agent.performance;
    
    // Update average task time
    perf.avgTaskTime = (perf.avgTaskTime * agent.tasksCompleted + duration) / (agent.tasksCompleted + 1);
    
    // Update success rate
    if (!success) {
      perf.successRate = (perf.successRate * agent.tasksCompleted) / (agent.tasksCompleted + 1);
    }
  }

  updateMetrics(task) {
    const duration = task.completed - task.started;
    const taskCount = this.metrics.tasksCompleted;
    
    this.metrics.avgCompletionTime = 
      (this.metrics.avgCompletionTime * (taskCount - 1) + duration) / taskCount;
  }

  async rebalanceSwarm(swarmId) {
    const swarm = this.swarms.get(swarmId);
    if (!swarm) return;
    
    // Remove least performing agents if over capacity
    while (swarm.agents.size > swarm.maxAgents) {
      let worstAgent = null;
      let worstScore = Infinity;
      
      for (const agentId of swarm.agents) {
        const agent = this.agents.get(agentId);
        const score = agent.performance.successRate * agent.tasksCompleted;
        
        if (score < worstScore && agent.status === 'idle') {
          worstScore = score;
          worstAgent = agentId;
        }
      }
      
      if (worstAgent) {
        swarm.agents.delete(worstAgent);
        this.agents.delete(worstAgent);
        this.emit('agent:removed', { agentId: worstAgent, reason: 'rebalance' });
      } else {
        break; // No idle agents to remove
      }
    }
  }

  /**
   * Get swarm status
   */
  getSwarmStatus(swarmId) {
    const swarm = this.swarms.get(swarmId);
    if (!swarm) return null;
    
    const agents = [];
    for (const agentId of swarm.agents) {
      const agent = this.agents.get(agentId);
      agents.push({
        id: agent.id,
        name: agent.name,
        type: agent.type,
        status: agent.status,
        tasksCompleted: agent.tasksCompleted
      });
    }
    
    const tasks = [];
    for (const taskId of swarm.tasks) {
      const task = this.tasks.get(taskId);
      tasks.push({
        id: task.id,
        status: task.status,
        progress: task.subtasks.filter(st => st.completed).length / task.subtasks.length
      });
    }
    
    return {
      id: swarm.id,
      topology: swarm.topology,
      status: swarm.status,
      agents,
      tasks,
      metrics: swarm.metrics
    };
  }

  /**
   * Destroy swarm
   */
  async destroySwarm(swarmId) {
    const swarm = this.swarms.get(swarmId);
    if (!swarm) return;
    
    // Stop all tasks
    for (const taskId of swarm.tasks) {
      const task = this.tasks.get(taskId);
      if (task && task.status === 'in_progress') {
        task.status = 'cancelled';
      }
    }
    
    // Remove all agents
    for (const agentId of swarm.agents) {
      this.agents.delete(agentId);
    }
    
    // Remove swarm
    this.swarms.delete(swarmId);
    
    this.emit('swarm:destroyed', { swarmId });
    
    return { destroyed: true };
  }
}

export default AgentCoordinator;