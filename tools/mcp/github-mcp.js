#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { Octokit } from '@octokit/rest';

// Initialize GitHub client
let octokit;

// Check if we're using PAT or GitHub App authentication
if (process.env.GITHUB_TOKEN) {
  // Personal Access Token authentication
  octokit = new Octokit({ auth: process.env.GITHUB_TOKEN });
} else if (process.env.GITHUB_APP_ID && process.env.GITHUB_INSTALLATION_ID && process.env.GITHUB_PRIVATE_KEY_PEM) {
  // GitHub App authentication - we'll need to generate a token on demand
  console.error('GitHub App authentication requires token generation on demand');
  process.exit(1);
} else {
  console.error('Missing GitHub credentials. Set either GITHUB_TOKEN or GitHub App credentials.');
  process.exit(1);
}

// Create MCP server
const server = new Server(
  {
    name: 'github-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      resources: {},
      tools: {
        getRepoInfo: {
          name: 'get_repo_info',
          description: 'Get repository information',
          inputSchema: {
            type: 'object',
            properties: {
              owner: {
                type: 'string',
                description: 'Repository owner'
              },
              repo: {
                type: 'string',
                description: 'Repository name'
              }
            },
            required: ['owner', 'repo']
          }
        },
        listRepos: {
          name: 'list_repos',
          description: 'List repositories for a user or organization',
          inputSchema: {
            type: 'object',
            properties: {
              username: {
                type: 'string',
                description: 'Username or organization name'
              },
              type: {
                type: 'string',
                description: 'Type: all, owner, member, public, private, forks, sources, internal',
                enum: ['all', 'owner', 'member', 'public', 'private', 'forks', 'sources', 'internal']
              }
            },
            required: ['username']
          }
        },
        searchRepos: {
          name: 'search_repos',
          description: 'Search repositories',
          inputSchema: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description: 'Search query'
              },
              sort: {
                type: 'string',
                description: 'Sort field: stars, forks, updated',
                enum: ['stars', 'forks', 'updated']
              },
              order: {
                type: 'string',
                description: 'Sort order: asc, desc',
                enum: ['asc', 'desc']
              },
              per_page: {
                type: 'number',
                description: 'Results per page (max 100)'
              }
            },
            required: ['query']
          }
        },
        getIssues: {
          name: 'get_issues',
          description: 'Get repository issues',
          inputSchema: {
            type: 'object',
            properties: {
              owner: {
                type: 'string',
                description: 'Repository owner'
              },
              repo: {
                type: 'string',
                description: 'Repository name'
              },
              state: {
                type: 'string',
                description: 'Issue state: open, closed, all',
                enum: ['open', 'closed', 'all']
              },
              labels: {
                type: 'string',
                description: 'Comma-separated list of labels'
              }
            },
            required: ['owner', 'repo']
          }
        },
        createIssue: {
          name: 'create_issue',
          description: 'Create a new issue',
          inputSchema: {
            type: 'object',
            properties: {
              owner: {
                type: 'string',
                description: 'Repository owner'
              },
              repo: {
                type: 'string',
                description: 'Repository name'
              },
              title: {
                type: 'string',
                description: 'Issue title'
              },
              body: {
                type: 'string',
                description: 'Issue body'
              },
              labels: {
                type: 'array',
                description: 'Array of labels',
                items: { type: 'string' }
              },
              assignees: {
                type: 'array',
                description: 'Array of assignees',
                items: { type: 'string' }
              }
            },
            required: ['owner', 'repo', 'title']
          }
        }
      }
    }
  }
);

// Get repository info tool
server.setRequestHandler('tools/get_repo_info', async (params) => {
  try {
    const { owner, repo } = params;
    const { data } = await octokit.repos.get({ owner, repo });
    
    return {
      content: [{
        type: 'text',
        text: JSON.stringify(data, null, 2)
      }]
    };
  } catch (error) {
    return {
      content: [{
        type: 'text',
        text: `Error: ${error.message}`
      }]
    };
  }
});

// List repositories tool
server.setRequestHandler('tools/list_repos', async (params) => {
  try {
    const { username, type = 'all' } = params;
    const { data } = await octokit.repos.listForUser({ username, type });
    
    return {
      content: [{
        type: 'text',
        text: JSON.stringify(data, null, 2)
      }]
    };
  } catch (error) {
    return {
      content: [{
        type: 'text',
        text: `Error: ${error.message}`
      }]
    };
  }
});

// Search repositories tool
server.setRequestHandler('tools/search_repos', async (params) => {
  try {
    const { query, sort = 'stars', order = 'desc', per_page = 30 } = params;
    const { data } = await octokit.search.repos({ q: query, sort, order, per_page });
    
    return {
      content: [{
        type: 'text',
        text: JSON.stringify(data.items, null, 2)
      }]
    };
  } catch (error) {
    return {
      content: [{
        type: 'text',
        text: `Error: ${error.message}`
      }]
    };
  }
});

// Get issues tool
server.setRequestHandler('tools/get_issues', async (params) => {
  try {
    const { owner, repo, state = 'open', labels } = params;
    const options = { owner, repo, state };
    
    if (labels) {
      options.labels = labels;
    }
    
    const { data } = await octokit.issues.listForRepo(options);
    
    return {
      content: [{
        type: 'text',
        text: JSON.stringify(data, null, 2)
      }]
    };
  } catch (error) {
    return {
      content: [{
        type: 'text',
        text: `Error: ${error.message}`
      }]
    };
  }
});

// Create issue tool
server.setRequestHandler('tools/create_issue', async (params) => {
  try {
    const { owner, repo, title, body, labels, assignees } = params;
    const options = { owner, repo, title };
    
    if (body) options.body = body;
    if (labels) options.labels = labels;
    if (assignees) options.assignees = assignees;
    
    const { data } = await octokit.issues.create(options);
    
    return {
      content: [{
        type: 'text',
        text: `Issue created successfully: ${JSON.stringify(data, null, 2)}`
      }]
    };
  } catch (error) {
    return {
      content: [{
        type: 'text',
        text: `Error: ${error.message}`
      }]
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('GitHub MCP server running on stdio');
}

main().catch(console.error);
