/**
 * MANDREL Project Management Handler
 * 
 * This handles all project management operations:
 * - Creating and managing projects
 * - Session state (current active project)
 * - Project switching for AI agents
 * - Project discovery and listing
 * 
 * This enables AI agents to seamlessly work across multiple projects!
 */

import { db } from '../config/database.js';
// Re-export types from shared types file (to avoid circular dependency with projectSwitchValidator)
export type { ProjectInfo, CreateProjectRequest, SessionState } from '../types/project.js';
// Import for internal use
import type { ProjectInfo, CreateProjectRequest, SessionState } from '../types/project.js';

export class ProjectHandler {
  // In-memory session state (in production, this could be Redis/database)
  private sessionStates = new Map<string, SessionState>();
  private defaultSessionId = 'default-session';

  /**
   * List all projects with optional statistics
   */
  async listProjects(includeStats: boolean = true): Promise<ProjectInfo[]> {
    console.log('📋 Listing all projects...');

    try {
      let sql = `
        SELECT 
          p.id, p.name, p.description, p.status, 
          p.created_at, p.updated_at, p.git_repo_url, 
          p.root_directory, p.metadata
      `;

      if (includeStats) {
        sql += `, COUNT(c.id) as context_count`;
      }

      sql += ` FROM projects p`;

      if (includeStats) {
        sql += ` LEFT JOIN contexts c ON p.id = c.project_id`;
      }

      sql += ` GROUP BY p.id, p.name, p.description, p.status, p.created_at, p.updated_at, p.git_repo_url, p.root_directory, p.metadata`;
      sql += ` ORDER BY p.updated_at DESC`;

      const result = await db.query(sql);

      // Get current project ID once before mapping (now async)
      const currentProjectId = await this.getCurrentProjectId();

      const projects: ProjectInfo[] = result.rows.map(row => ({
        id: row.id,
        name: row.name,
        description: row.description,
        status: row.status,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        gitRepoUrl: row.git_repo_url,
        rootDirectory: row.root_directory,
        metadata: typeof row.metadata === 'string' ? JSON.parse(row.metadata) : row.metadata,
        contextCount: includeStats ? parseInt(row.context_count || '0') : undefined,
        isActive: currentProjectId === row.id
      }));

      console.log(`✅ Found ${projects.length} projects`);
      return projects;

    } catch (error) {
      console.error('❌ Failed to list projects:', error);
      throw new Error(`Failed to list projects: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Create a new project
   */
  async createProject(request: CreateProjectRequest): Promise<ProjectInfo> {
    console.log(`🆕 Creating new project: "${request.name}"`);

    try {
      // Validate name uniqueness
      const existingCheck = await db.query('SELECT id FROM projects WHERE name = $1', [request.name]);
      if (existingCheck.rows.length > 0) {
        throw new Error(`Project with name "${request.name}" already exists`);
      }

      // Insert new project
      const result = await db.query(`
        INSERT INTO projects (name, description, git_repo_url, root_directory, metadata)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *
      `, [
        request.name,
        request.description || null,
        request.gitRepoUrl || null,
        request.rootDirectory || null,
        JSON.stringify(request.metadata || {})
      ]);

      const row = result.rows[0];
      const project: ProjectInfo = {
        id: row.id,
        name: row.name,
        description: row.description,
        status: row.status,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        gitRepoUrl: row.git_repo_url,
        rootDirectory: row.root_directory,
        metadata: typeof row.metadata === 'string' ? JSON.parse(row.metadata) : row.metadata,
        contextCount: 0
      };

      console.log(`✅ Created project: ${project.id}`);
      return project;

    } catch (error) {
      console.error('❌ Failed to create project:', error);
      throw new Error(`Failed to create project: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get project details by ID or name
   */
  async getProject(identifier: string): Promise<ProjectInfo | null> {
    console.log(`🔍 Getting project: "${identifier}"`);

    try {
      // Try by ID first (UUID format), then by name
      const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(identifier);
      
      const field = isUUID ? 'id' : 'name';
      const result = await db.query(`
        SELECT 
          p.id, p.name, p.description, p.status,
          p.created_at, p.updated_at, p.git_repo_url,
          p.root_directory, p.metadata,
          COUNT(c.id) as context_count
        FROM projects p
        LEFT JOIN contexts c ON p.id = c.project_id
        WHERE p.${field} = $1
        GROUP BY p.id, p.name, p.description, p.status, p.created_at, p.updated_at, p.git_repo_url, p.root_directory, p.metadata
      `, [identifier]);

      if (result.rows.length === 0) {
        return null;
      }

      const row = result.rows[0];

      // Get current project ID (now async)
      const currentProjectId = await this.getCurrentProjectId();

      const project: ProjectInfo = {
        id: row.id,
        name: row.name,
        description: row.description,
        status: row.status,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        gitRepoUrl: row.git_repo_url,
        rootDirectory: row.root_directory,
        metadata: typeof row.metadata === 'string' ? JSON.parse(row.metadata) : row.metadata,
        contextCount: parseInt(row.context_count || '0'),
        isActive: currentProjectId === row.id
      };

      console.log(`✅ Found project: ${project.name} (${project.contextCount} contexts)`);
      return project;

    } catch (error) {
      console.error('❌ Failed to get project:', error);
      throw new Error(`Failed to get project: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Set the current active project for the session
   */
  setCurrentProject(projectId: string, sessionId: string = this.defaultSessionId, manualOverride: boolean = false): void {
    console.log(`🔄 Setting current project to: ${projectId} (session: ${sessionId}, manual: ${manualOverride})`);

    const existing = this.sessionStates.get(sessionId) || {};
    this.sessionStates.set(sessionId, {
      ...existing,
      currentProjectId: projectId,
      sessionId,
      manualOverride  // Store whether this was a manual switch
    });

    console.log(`✅ Current project set for session ${sessionId}${manualOverride ? ' (manual override)' : ''}`);
  }

  /**
   * Clear all session caches - forces re-initialization on next access
   * Used when primary project changes to ensure sessions sync with new default
   */
  clearSessionCache(): void {
    console.log('🗑️  Clearing all session caches');
    const sessionCount = this.sessionStates.size;
    this.sessionStates.clear();
    console.log(`✅ Cleared ${sessionCount} session cache(s)`);
  }

  /**
   * Get the current active project ID
   * Now async with cache validation to prevent stale project IDs
   */
  async getCurrentProjectId(sessionId: string = this.defaultSessionId): Promise<string | null> {
    const state = this.sessionStates.get(sessionId);
    const cachedId = state?.currentProjectId;

    if (!cachedId) {
      return null;
    }

    // Validate cached ID still exists in database
    const result = await db.query(
      'SELECT 1 FROM projects WHERE id = $1',
      [cachedId]
    );

    if (result.rows.length === 0) {
      // Clear invalid cached state
      console.warn(`Clearing stale project cache for session ${sessionId}: project ${cachedId} no longer exists`);
      this.sessionStates.delete(sessionId);
      return null;
    }

    return cachedId;
  }

  /**
   * Get the current active project details
   */
  async getCurrentProject(sessionId: string = this.defaultSessionId): Promise<ProjectInfo | null> {
    const projectId = await this.getCurrentProjectId(sessionId);
    if (!projectId) {
      return null;
    }

    return await this.getProject(projectId);
  }

  /**
   * Switch to a project (by ID or name) and set as current
   * Enhanced with TS012 validation framework
   */
  async switchProject(identifier: string, sessionId: string = this.defaultSessionId): Promise<ProjectInfo> {
    console.log(`🔄 Switching to project: "${identifier}" (session: ${sessionId.substring(0, 8)}...)`);

    // Basic validation for backwards compatibility
    const project = await this.getProject(identifier);
    if (!project) {
      throw new Error(`Project "${identifier}" not found`);
    }

    // Mark as manual override so initializeSession() won't override this choice
    this.setCurrentProject(project.id, sessionId, true);

    console.log(`✅ Switched to project: ${project.name}`);
    return { ...project, isActive: true };
  }

  // Note: switchProjectWithValidation moved to projectSwitchValidator.ts to avoid circular dependency
  // Use ProjectSwitchValidator.switchProjectWithValidation() instead

  /**
   * Get session state information
   */
  getSessionInfo(sessionId: string = this.defaultSessionId): SessionState {
    return this.sessionStates.get(sessionId) || {
      currentProjectId: null,
      sessionId
    };
  }

  /**
   * Initialize session with default project (if available)
   */
  async initializeSession(sessionId: string = this.defaultSessionId): Promise<ProjectInfo | null> {
    console.log(`🔄 Initializing session: ${sessionId}`);

    // Get all projects first
    const projects = await this.listProjects(false);
    if (projects.length === 0) {
      console.log('⚠️  No projects available');
      return null;
    }

    // Priority 0: Check if user manually switched - respect their choice!
    const sessionState = this.sessionStates.get(sessionId);
    const existing = await this.getCurrentProjectId(sessionId);

    if (sessionState?.manualOverride && existing) {
      const manualProject = await this.getProject(existing);
      if (manualProject) {
        console.log(`✅ Respecting manual project switch: ${manualProject.name}`);
        return { ...manualProject, isActive: true };
      }
    }

    // Priority 1: Check for primary project (respects user's default preference)
    const primaryProject = projects.find(p => p.metadata && p.metadata.is_primary === true);

    if (primaryProject) {
      console.log(`✅ Found primary project: ${primaryProject.name}`);

      // Check if we're already on the primary project
      if (existing === primaryProject.id) {
        console.log(`✅ Already on primary project: ${primaryProject.name}`);
        return { ...primaryProject, isActive: true };
      }

      // Switch from cached project to primary
      if (existing) {
        const old = await this.getProject(existing);
        console.log(`🔄 Switching from ${old?.name} to primary project: ${primaryProject.name}`);
      }

      this.setCurrentProject(primaryProject.id, sessionId);
      return { ...primaryProject, isActive: true };
    }

    // Priority 2: No primary - check cached session state
    if (existing) {
      const project = await this.getProject(existing);
      if (project) {
        console.log(`✅ Using cached project: ${project.name} (no primary set)`);
        return project;
      }
    }

    // Priority 3: Fall back to system defaults
    let defaultProject = projects.find(p => p.name === 'mandrel-bootstrap');
    if (defaultProject) {
      console.log(`✅ Using system default project: ${defaultProject.name}`);
    } else {
      // Priority 4: Use first available project
      defaultProject = projects[0];
      console.log(`✅ Using first available project: ${defaultProject.name}`);
    }

    this.setCurrentProject(defaultProject.id, sessionId);
    console.log(`✅ Session initialized with project: ${defaultProject.name}`);

    return { ...defaultProject, isActive: true };
  }

  /**
   * Update project details
   */
  async updateProject(projectId: string, updates: Partial<CreateProjectRequest>): Promise<ProjectInfo> {
    console.log(`📝 Updating project: ${projectId}`);

    try {
      // Build dynamic update query
      const updateFields = [];
      const values = [];
      let paramIndex = 1;

      if (updates.name !== undefined) {
        updateFields.push(`name = $${paramIndex}`);
        values.push(updates.name);
        paramIndex++;
      }

      if (updates.description !== undefined) {
        updateFields.push(`description = $${paramIndex}`);
        values.push(updates.description);
        paramIndex++;
      }

      if (updates.gitRepoUrl !== undefined) {
        updateFields.push(`git_repo_url = $${paramIndex}`);
        values.push(updates.gitRepoUrl);
        paramIndex++;
      }

      if (updates.rootDirectory !== undefined) {
        updateFields.push(`root_directory = $${paramIndex}`);
        values.push(updates.rootDirectory);
        paramIndex++;
      }

      if (updates.metadata !== undefined) {
        updateFields.push(`metadata = $${paramIndex}`);
        values.push(JSON.stringify(updates.metadata));
        paramIndex++;
      }

      if (updateFields.length === 0) {
        throw new Error('No update fields provided');
      }

      updateFields.push(`updated_at = CURRENT_TIMESTAMP`);
      values.push(projectId);

      const sql = `
        UPDATE projects 
        SET ${updateFields.join(', ')}
        WHERE id = $${paramIndex}
        RETURNING *
      `;

      const result = await db.query(sql, values);
      
      if (result.rows.length === 0) {
        throw new Error(`Project ${projectId} not found`);
      }

      const row = result.rows[0];

      // Get current project ID (now async)
      const currentProjectId = await this.getCurrentProjectId();

      const project: ProjectInfo = {
        id: row.id,
        name: row.name,
        description: row.description,
        status: row.status,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        gitRepoUrl: row.git_repo_url,
        rootDirectory: row.root_directory,
        metadata: typeof row.metadata === 'string' ? JSON.parse(row.metadata) : row.metadata,
        isActive: currentProjectId === row.id
      };

      console.log(`✅ Updated project: ${project.name}`);
      return project;

    } catch (error) {
      console.error('❌ Failed to update project:', error);
      throw new Error(`Failed to update project: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
    * Migrate one project into another (consolidate two projects)
    * Moves all contexts, tasks, and decisions from source to target, then deletes source
    */
  async migrateProject(sourceProjectId: string, targetProjectId: string, confirmed: boolean = false): Promise<{ success: boolean; requiresConfirmation: boolean; migrationSummary?: { movedAnalyticsEvents: number; movedContexts: number; movedTasks: number; movedDecisions: number; sourceProjectName: string; targetProjectName: string }; warning?: string }> {
    console.log(`🔄 Project migration requested: ${sourceProjectId} → ${targetProjectId} (confirmed: ${confirmed})`);

    try {
      // Verify both projects exist
      const sourceResult = await db.query('SELECT * FROM projects WHERE id = $1', [sourceProjectId]);
      if (sourceResult.rows.length === 0) {
        throw new Error(`Source project not found: ${sourceProjectId}`);
      }
      const sourceProject = sourceResult.rows[0];

      const targetResult = await db.query('SELECT * FROM projects WHERE id = $1', [targetProjectId]);
      if (targetResult.rows.length === 0) {
        throw new Error(`Target project not found: ${targetProjectId}`);
      }
      const targetProject = targetResult.rows[0];

      // Count items to migrate
      const analyticsResult = await db.query('SELECT COUNT(*) as count FROM analytics_events WHERE project_id = $1', [sourceProjectId]);
      const contextsResult = await db.query('SELECT COUNT(*) as count FROM contexts WHERE project_id = $1', [sourceProjectId]);
      const tasksResult = await db.query('SELECT COUNT(*) as count FROM tasks WHERE project_id = $1', [sourceProjectId]);
      const decisionsResult = await db.query('SELECT COUNT(*) as count FROM technical_decisions WHERE project_id = $1', [sourceProjectId]);

      const counts = {
        analyticsEvents: parseInt(analyticsResult.rows[0].count || '0'),
        contexts: parseInt(contextsResult.rows[0].count || '0'),
        tasks: parseInt(tasksResult.rows[0].count || '0'),
        decisions: parseInt(decisionsResult.rows[0].count || '0')
      };

      // If not confirmed, return warning
      if (!confirmed) {
        const totalItems = Object.values(counts).reduce((a, b) => a + b, 0);
        console.log(`⚠️  Project migration requires confirmation. Would move: ${totalItems} items`);
        return {
          success: false,
          requiresConfirmation: true,
          warning: `⚠️  CONSOLIDATION: Migrating "${sourceProject.name}" into "${targetProject.name}" will move:
  • ${counts.analyticsEvents} analytics events
  • ${counts.contexts} contexts
  • ${counts.tasks} tasks
  • ${counts.decisions} decisions
  
After migration, "${sourceProject.name}" will be deleted.
To confirm migration, call this tool again with confirmed: true`
        };
      }

      // Migrate analytics events first (has foreign key constraint)
      if (counts.analyticsEvents > 0) {
        await db.query('UPDATE analytics_events SET project_id = $1 WHERE project_id = $2', [targetProjectId, sourceProjectId]);
        console.log(`✅ Migrated ${counts.analyticsEvents} analytics events`);
      }

      // Migrate contexts
      if (counts.contexts > 0) {
        await db.query('UPDATE contexts SET project_id = $1 WHERE project_id = $2', [targetProjectId, sourceProjectId]);
        console.log(`✅ Migrated ${counts.contexts} contexts`);
      }

      // Migrate tasks
      if (counts.tasks > 0) {
        await db.query('UPDATE tasks SET project_id = $1 WHERE project_id = $2', [targetProjectId, sourceProjectId]);
        console.log(`✅ Migrated ${counts.tasks} tasks`);
      }

      // Migrate decisions
      if (counts.decisions > 0) {
        await db.query('UPDATE technical_decisions SET project_id = $1 WHERE project_id = $2', [targetProjectId, sourceProjectId]);
        console.log(`✅ Migrated ${counts.decisions} decisions`);
      }

      // Delete source project (CASCADE will handle any remaining relationships)
      await db.query('DELETE FROM projects WHERE id = $1', [sourceProjectId]);
      console.log(`✅ Deleted source project: ${sourceProject.name}`);

      return {
        success: true,
        requiresConfirmation: false,
        migrationSummary: {
          movedAnalyticsEvents: counts.analyticsEvents,
          movedContexts: counts.contexts,
          movedTasks: counts.tasks,
          movedDecisions: counts.decisions,
          sourceProjectName: sourceProject.name,
          targetProjectName: targetProject.name
        }
      };

    } catch (error) {
      console.error('❌ Failed to migrate project:', error);
      throw new Error(`Failed to migrate project: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
    * Delete a project by ID
    * Cascade deletes contexts, tasks, decisions, and analytics events in that project
    * Prevents deletion if it's the current project
    * Requires explicit confirmation to prevent accidental deletion
    */
  async deleteProject(projectId: string, confirmed: boolean = false): Promise<{ success: boolean; requiresConfirmation: boolean; deletedProject?: ProjectInfo; deletedCount?: { analyticsEvents: number; contexts: number; tasks: number; decisions: number }; warning?: string }> {
    console.log(`🗑️  Delete project requested: ${projectId} (confirmed: ${confirmed})`);

    try {
      // Check if trying to delete current project
      const currentProjectId = await this.getCurrentProjectId();
      if (currentProjectId === projectId) {
        throw new Error('Cannot delete the currently active project. Switch to another project first.');
      }

      // Get project details
      const projectResult = await db.query('SELECT * FROM projects WHERE id = $1', [projectId]);
      if (projectResult.rows.length === 0) {
        throw new Error(`Project not found: ${projectId}`);
      }
      const projectRow = projectResult.rows[0];

      // Count what will be deleted
      const analyticsResult = await db.query('SELECT COUNT(*) as count FROM analytics_events WHERE project_id = $1', [projectId]);
      const contextsResult = await db.query('SELECT COUNT(*) as count FROM contexts WHERE project_id = $1', [projectId]);
      const tasksResult = await db.query('SELECT COUNT(*) as count FROM tasks WHERE project_id = $1', [projectId]);
      const decisionsResult = await db.query('SELECT COUNT(*) as count FROM technical_decisions WHERE project_id = $1', [projectId]);

      const deletedCount = {
        analyticsEvents: parseInt(analyticsResult.rows[0].count || '0'),
        contexts: parseInt(contextsResult.rows[0].count || '0'),
        tasks: parseInt(tasksResult.rows[0].count || '0'),
        decisions: parseInt(decisionsResult.rows[0].count || '0')
      };

      // If not confirmed, return warning with counts
      if (!confirmed) {
        const totalItems = Object.values(deletedCount).reduce((a, b) => a + b, 0);
        console.log(`⚠️  Project deletion requires confirmation. Would delete: ${totalItems} items`);
        return {
          success: false,
          requiresConfirmation: true,
          warning: `⚠️  DESTRUCTIVE OPERATION: Deleting project "${projectRow.name}" will permanently remove:
  • ${deletedCount.analyticsEvents} analytics events
  • ${deletedCount.contexts} contexts
  • ${deletedCount.tasks} tasks
  • ${deletedCount.decisions} decisions
  
To confirm deletion, call this tool again with confirmed: true`
        };
      }

      // Delete analytics events first
      if (deletedCount.analyticsEvents > 0) {
        await db.query('DELETE FROM analytics_events WHERE project_id = $1', [projectId]);
      }

      // Delete project (CASCADE will delete contexts, tasks, decisions)
      await db.query('DELETE FROM projects WHERE id = $1', [projectId]);

      console.log(`✅ Deleted project: ${projectRow.name} (${deletedCount.analyticsEvents} analytics events, ${deletedCount.contexts} contexts, ${deletedCount.tasks} tasks, ${deletedCount.decisions} decisions)`);

      return {
        success: true,
        requiresConfirmation: false,
        deletedProject: {
          id: projectRow.id,
          name: projectRow.name,
          description: projectRow.description,
          status: projectRow.status,
          createdAt: projectRow.created_at,
          updatedAt: projectRow.updated_at,
          gitRepoUrl: projectRow.git_repo_url,
          rootDirectory: projectRow.root_directory,
          metadata: typeof projectRow.metadata === 'string' ? JSON.parse(projectRow.metadata) : projectRow.metadata
        },
        deletedCount
      };

    } catch (error) {
      console.error('❌ Failed to delete project:', error);
      throw new Error(`Failed to delete project: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }
}

// Export singleton instance
export const projectHandler = new ProjectHandler();
