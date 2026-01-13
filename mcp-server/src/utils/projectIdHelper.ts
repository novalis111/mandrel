/**
 * Helper utilities for projectId validation and error responses
 * Prevents data leaks by ensuring projectId is always provided
 */

import { db } from '../config/database.js';
import type { McpResponse } from './mcpFormatter.js';

export interface ProjectInfo {
  id: string;
  name: string;
  description: string | null;
}

/**
 * Get list of available projects formatted for display
 */
export async function getAvailableProjects(): Promise<ProjectInfo[]> {
  const result = await db.query(
    'SELECT id, name, description FROM projects ORDER BY created_at DESC'
  );
  return result.rows;
}

/**
 * Format projects list for MCP response
 */
export function formatProjectsList(projects: ProjectInfo[]): string {
  return projects.map((p, i) => 
    `${i + 1}. **${p.name}** (ID: ${p.id})\n   ${p.description || 'No description'}`
  ).join('\n\n');
}

/**
 * Create error response when projectId is missing
 * Includes list of available projects for easy selection
 */
export async function projectIdMissingResponse(toolName: string): Promise<McpResponse> {
  try {
    const projects = await getAvailableProjects();
    const projectsList = formatProjectsList(projects);

    return {
      content: [{
        type: 'text',
        text: `❌ projectId is REQUIRED to prevent cross-project data leaks.\n\n` +
              `📋 Available Projects:\n\n${projectsList}\n\n` +
              `Usage: ${toolName} { projectId: "<project-id>" }`
      }],
    };
  } catch (error) {
    // Fallback if project list fetch fails
    return {
      content: [{
        type: 'text',
        text: `❌ projectId is REQUIRED to prevent cross-project data leaks.\n\n` +
              `Please use project_list to find your project ID, then retry with: ${toolName} { projectId: "<project-id>" }`
      }],
    };
  }
}
