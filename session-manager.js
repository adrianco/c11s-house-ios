/**
 * Claude Flow Session Manager
 * Manages persistent sessions, state, and context across Claude Code interactions
 */

import { randomUUID } from 'crypto';
import { readFile, writeFile } from 'fs/promises';
import { existsSync } from 'fs';
import { join } from 'path';

export class SessionManager {
  constructor(options = {}) {
    this.sessionPath = options.sessionPath || './memory/sessions';
    this.currentSession = null;
    this.sessionHistory = [];
    this.maxHistorySize = options.maxHistorySize || 100;
    this.autoSave = options.autoSave !== false;
    this.autoSaveInterval = options.autoSaveInterval || 30000; // 30 seconds
    this.autoSaveTimer = null;
  }

  async initialize() {
    // Load session history
    await this.loadSessionHistory();
    
    // Start auto-save if enabled
    if (this.autoSave) {
      this.startAutoSave();
    }
  }

  /**
   * Create a new session
   */
  async createSession(options = {}) {
    const sessionId = options.sessionId || randomUUID();
    const type = options.type || 'development';
    const metadata = options.metadata || {};

    const session = {
      id: sessionId,
      type,
      metadata,
      created: Date.now(),
      lastActive: Date.now(),
      state: {
        swarms: [],
        agents: [],
        tasks: [],
        memory: {},
        metrics: {
          tokensUsed: 0,
          tasksCompleted: 0,
          timeActive: 0,
          efficiency: 1.0
        }
      },
      context: {
        workingDirectory: process.cwd(),
        environment: process.env.NODE_ENV || 'development',
        claudeFlowVersion: '2.0.0-alpha.27',
        features: await this.detectFeatures()
      },
      events: [],
      checkpoints: []
    };

    this.currentSession = session;
    this.sessionHistory.push({
      id: sessionId,
      created: session.created,
      type: session.type
    });

    // Save initial session
    await this.saveSession();

    return { sessionId, created: session.created };
  }

  /**
   * Load an existing session
   */
  async loadSession(sessionId) {
    const sessionFile = join(this.sessionPath, `${sessionId}.json`);
    
    if (!existsSync(sessionFile)) {
      throw new Error(`Session ${sessionId} not found`);
    }

    const sessionData = await readFile(sessionFile, 'utf8');
    this.currentSession = JSON.parse(sessionData);
    this.currentSession.lastActive = Date.now();

    return this.currentSession;
  }

  /**
   * Save current session
   */
  async saveSession() {
    if (!this.currentSession) {
      return;
    }

    const sessionFile = join(this.sessionPath, `${this.currentSession.id}.json`);
    
    // Update last active time
    this.currentSession.lastActive = Date.now();
    
    // Calculate time active
    if (this.currentSession.state.metrics) {
      const sessionAge = Date.now() - this.currentSession.created;
      this.currentSession.state.metrics.timeActive = sessionAge;
    }

    await writeFile(
      sessionFile,
      JSON.stringify(this.currentSession, null, 2),
      'utf8'
    );

    // Update history
    await this.saveSessionHistory();
  }

  /**
   * Update session state
   */
  async updateState(updates) {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    // Merge updates into current state
    this.currentSession.state = {
      ...this.currentSession.state,
      ...updates
    };

    // Add event
    this.addEvent('state_updated', { updates });

    // Auto-save if enabled
    if (this.autoSave) {
      await this.saveSession();
    }
  }

  /**
   * Add swarm to session
   */
  async addSwarm(swarmId, swarmInfo) {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    this.currentSession.state.swarms.push({
      id: swarmId,
      ...swarmInfo,
      addedAt: Date.now()
    });

    this.addEvent('swarm_added', { swarmId, ...swarmInfo });
  }

  /**
   * Add agent to session
   */
  async addAgent(agentId, agentInfo) {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    this.currentSession.state.agents.push({
      id: agentId,
      ...agentInfo,
      addedAt: Date.now()
    });

    this.addEvent('agent_added', { agentId, ...agentInfo });
  }

  /**
   * Add task to session
   */
  async addTask(taskId, taskInfo) {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    this.currentSession.state.tasks.push({
      id: taskId,
      ...taskInfo,
      addedAt: Date.now()
    });

    this.addEvent('task_added', { taskId, ...taskInfo });
  }

  /**
   * Update memory
   */
  async updateMemory(key, value) {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    this.currentSession.state.memory[key] = {
      value,
      updated: Date.now()
    };

    this.addEvent('memory_updated', { key, size: JSON.stringify(value).length });
  }

  /**
   * Update metrics
   */
  async updateMetrics(metrics) {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    this.currentSession.state.metrics = {
      ...this.currentSession.state.metrics,
      ...metrics
    };

    this.addEvent('metrics_updated', { metrics });
  }

  /**
   * Create checkpoint
   */
  async createCheckpoint(name, description) {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    const checkpoint = {
      id: randomUUID(),
      name,
      description,
      created: Date.now(),
      state: JSON.parse(JSON.stringify(this.currentSession.state))
    };

    this.currentSession.checkpoints.push(checkpoint);
    this.addEvent('checkpoint_created', { checkpointId: checkpoint.id, name });

    await this.saveSession();

    return { checkpointId: checkpoint.id };
  }

  /**
   * Restore from checkpoint
   */
  async restoreCheckpoint(checkpointId) {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    const checkpoint = this.currentSession.checkpoints.find(
      cp => cp.id === checkpointId
    );

    if (!checkpoint) {
      throw new Error(`Checkpoint ${checkpointId} not found`);
    }

    // Restore state
    this.currentSession.state = JSON.parse(JSON.stringify(checkpoint.state));
    this.addEvent('checkpoint_restored', { checkpointId, name: checkpoint.name });

    await this.saveSession();

    return { restored: true, checkpoint: checkpoint.name };
  }

  /**
   * Generate session summary
   */
  async generateSummary() {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    const session = this.currentSession;
    const duration = Date.now() - session.created;

    const summary = {
      sessionId: session.id,
      type: session.type,
      duration: this.formatDuration(duration),
      created: new Date(session.created).toISOString(),
      lastActive: new Date(session.lastActive).toISOString(),
      statistics: {
        swarms: session.state.swarms.length,
        agents: session.state.agents.length,
        tasks: session.state.tasks.length,
        tasksCompleted: session.state.metrics.tasksCompleted,
        tokensUsed: session.state.metrics.tokensUsed,
        efficiency: session.state.metrics.efficiency,
        events: session.events.length,
        checkpoints: session.checkpoints.length
      },
      topEvents: this.getTopEvents(session.events, 10),
      recentActivity: this.getRecentActivity(session.events, 5)
    };

    return summary;
  }

  /**
   * Export session
   */
  async exportSession(format = 'json') {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    const summary = await this.generateSummary();

    switch (format) {
      case 'json':
        return {
          session: this.currentSession,
          summary
        };

      case 'markdown':
        return this.generateMarkdownReport(this.currentSession, summary);

      default:
        throw new Error(`Unsupported export format: ${format}`);
    }
  }

  /**
   * End session
   */
  async endSession() {
    if (!this.currentSession) {
      throw new Error('No active session');
    }

    // Generate final summary
    const summary = await this.generateSummary();

    // Add final event
    this.addEvent('session_ended', { summary });

    // Save final state
    await this.saveSession();

    // Clear current session
    this.currentSession = null;

    // Stop auto-save
    if (this.autoSaveTimer) {
      clearInterval(this.autoSaveTimer);
      this.autoSaveTimer = null;
    }

    return summary;
  }

  /**
   * Helper methods
   */

  addEvent(type, data) {
    if (!this.currentSession) return;

    this.currentSession.events.push({
      id: randomUUID(),
      type,
      data,
      timestamp: Date.now()
    });

    // Limit event history
    if (this.currentSession.events.length > 1000) {
      this.currentSession.events = this.currentSession.events.slice(-1000);
    }
  }

  async detectFeatures() {
    // Detect available features
    return {
      mcp: true,
      swarms: true,
      neural: true,
      github: false,
      workflows: true
    };
  }

  formatDuration(ms) {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);

    if (hours > 0) {
      return `${hours}h ${minutes % 60}m`;
    } else if (minutes > 0) {
      return `${minutes}m ${seconds % 60}s`;
    } else {
      return `${seconds}s`;
    }
  }

  getTopEvents(events, limit) {
    const eventCounts = {};
    
    for (const event of events) {
      eventCounts[event.type] = (eventCounts[event.type] || 0) + 1;
    }

    return Object.entries(eventCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([type, count]) => ({ type, count }));
  }

  getRecentActivity(events, limit) {
    return events
      .slice(-limit)
      .reverse()
      .map(event => ({
        type: event.type,
        timestamp: new Date(event.timestamp).toISOString(),
        summary: this.summarizeEvent(event)
      }));
  }

  summarizeEvent(event) {
    switch (event.type) {
      case 'swarm_added':
        return `Added ${event.data.topology} swarm`;
      case 'agent_added':
        return `Spawned ${event.data.type} agent: ${event.data.name}`;
      case 'task_added':
        return `Started task: ${event.data.description?.substring(0, 50)}...`;
      case 'checkpoint_created':
        return `Created checkpoint: ${event.data.name}`;
      default:
        return event.type.replace(/_/g, ' ');
    }
  }

  generateMarkdownReport(session, summary) {
    let report = `# Claude Flow Session Report\n\n`;
    report += `## Session Information\n`;
    report += `- **ID**: ${summary.sessionId}\n`;
    report += `- **Type**: ${summary.type}\n`;
    report += `- **Duration**: ${summary.duration}\n`;
    report += `- **Created**: ${summary.created}\n`;
    report += `- **Last Active**: ${summary.lastActive}\n\n`;

    report += `## Statistics\n`;
    report += `- **Swarms**: ${summary.statistics.swarms}\n`;
    report += `- **Agents**: ${summary.statistics.agents}\n`;
    report += `- **Tasks**: ${summary.statistics.tasks}\n`;
    report += `- **Tasks Completed**: ${summary.statistics.tasksCompleted}\n`;
    report += `- **Tokens Used**: ${summary.statistics.tokensUsed}\n`;
    report += `- **Efficiency**: ${(summary.statistics.efficiency * 100).toFixed(1)}%\n\n`;

    report += `## Top Events\n`;
    for (const event of summary.topEvents) {
      report += `- ${event.type}: ${event.count} occurrences\n`;
    }
    report += `\n`;

    report += `## Recent Activity\n`;
    for (const activity of summary.recentActivity) {
      report += `- [${activity.timestamp}] ${activity.summary}\n`;
    }

    return report;
  }

  async loadSessionHistory() {
    const historyFile = join(this.sessionPath, 'history.json');
    
    if (existsSync(historyFile)) {
      const data = await readFile(historyFile, 'utf8');
      this.sessionHistory = JSON.parse(data);
    }
  }

  async saveSessionHistory() {
    const historyFile = join(this.sessionPath, 'history.json');
    
    // Limit history size
    if (this.sessionHistory.length > this.maxHistorySize) {
      this.sessionHistory = this.sessionHistory.slice(-this.maxHistorySize);
    }

    await writeFile(
      historyFile,
      JSON.stringify(this.sessionHistory, null, 2),
      'utf8'
    );
  }

  startAutoSave() {
    this.autoSaveTimer = setInterval(async () => {
      if (this.currentSession) {
        await this.saveSession();
      }
    }, this.autoSaveInterval);
  }

  /**
   * Get session list
   */
  async listSessions() {
    return this.sessionHistory.map(session => ({
      id: session.id,
      type: session.type,
      created: new Date(session.created).toISOString(),
      age: this.formatDuration(Date.now() - session.created)
    }));
  }

  /**
   * Clean old sessions
   */
  async cleanOldSessions(maxAge = 7 * 24 * 60 * 60 * 1000) { // 7 days
    const now = Date.now();
    const sessionsToKeep = [];
    
    for (const session of this.sessionHistory) {
      if (now - session.created < maxAge) {
        sessionsToKeep.push(session);
      } else {
        // Delete old session file
        const sessionFile = join(this.sessionPath, `${session.id}.json`);
        if (existsSync(sessionFile)) {
          const { unlink } = await import('fs/promises');
          await unlink(sessionFile);
        }
      }
    }
    
    this.sessionHistory = sessionsToKeep;
    await this.saveSessionHistory();
  }
}

export default SessionManager;