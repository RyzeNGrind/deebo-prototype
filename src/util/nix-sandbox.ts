import { exec, spawn } from 'child_process';
import { promisify } from 'util';
import { writeFile, mkdir, readFile } from 'fs/promises';
import { join, dirname } from 'path';

const execPromise = promisify(exec);

export interface NixSandboxConfig {
  name: string;
  code: string;
  language?: 'bash' | 'python' | 'nodejs' | 'typescript';
  allowedPaths?: string[];
  env?: Record<string, string>;
  timeout?: number;
}

export interface NixSandboxResult {
  success: boolean;
  exitCode: number;
  stdout: string;
  stderr: string;
  logPath: string;
  resultPath: string;
}

/**
 * Nix-native sandbox execution using Nix's built-in isolation
 * Replaces Docker-based sandboxing with Nix derivations
 */
export class NixSandboxExecutor {
  private isNixAvailable: boolean = false;
  private nixUtilsPath: string;
  private deeboRoot: string;

  constructor(deeboRoot: string) {
    this.deeboRoot = deeboRoot;
    this.nixUtilsPath = process.env.DEEBO_NIX_UTILS_PATH || join(deeboRoot, 'nix', 'sandbox-utils.nix');
    this.checkNixAvailability();
  }

  private async checkNixAvailability(): Promise<void> {
    try {
      await execPromise('nix --version');
      this.isNixAvailable = true;
      console.log('Nix sandbox mode enabled');
    } catch (error) {
      this.isNixAvailable = false;
      console.warn('Nix not available, falling back to standard execution');
    }
  }

  /**
   * Execute code in Nix sandbox with strict isolation
   */
  async executeSandboxed(config: NixSandboxConfig): Promise<NixSandboxResult> {
    if (!this.isNixAvailable) {
      return this.fallbackExecution(config);
    }

    const sessionDir = join(this.deeboRoot, 'memory-bank', 'nix-sandbox', config.name);
    await mkdir(sessionDir, { recursive: true });

    // Create Nix expression for sandboxed execution
    const nixExpr = this.generateNixExpression(config);
    const nixExprPath = join(sessionDir, 'execution.nix');
    await writeFile(nixExprPath, nixExpr);

    try {
      // Execute with Nix sandbox
      const { stdout, stderr } = await execPromise(
        `nix-build ${nixExprPath} --no-out-link --option sandbox true`,
        { 
          timeout: config.timeout || 30000,
          cwd: sessionDir 
        }
      );

      const resultPath = stdout.trim();
      const logContent = await this.readSandboxLogs(resultPath);

      return {
        success: true,
        exitCode: 0,
        stdout: logContent.stdout || '',
        stderr: logContent.stderr || '',
        logPath: join(resultPath, 'logs'),
        resultPath
      };
    } catch (error: any) {
      return {
        success: false,
        exitCode: error.code || 1,
        stdout: '',
        stderr: error.message,
        logPath: sessionDir,
        resultPath: sessionDir
      };
    }
  }

  /**
   * Execute Git operations in Nix sandbox
   */
  async executeGitSandboxed(repoPath: string, commands: string[]): Promise<NixSandboxResult> {
    if (!this.isNixAvailable) {
      return this.fallbackGitExecution(repoPath, commands);
    }

    const sessionDir = join(this.deeboRoot, 'memory-bank', 'nix-sandbox', `git-${Date.now()}`);
    await mkdir(sessionDir, { recursive: true });

    const nixExpr = `
{ pkgs ? import <nixpkgs> {} }:

pkgs.runCommand "git-sandbox" {
  buildInputs = with pkgs; [ git ];
  __noChroot = false;
  allowSubstitutes = false;
} ''
  mkdir -p $out/logs
  
  # Copy repository to sandbox (read-only)
  cp -r ${repoPath} ./repo
  cd ./repo
  
  ${commands.map(cmd => `
    echo "Executing: ${cmd}" | tee -a $out/logs/git.log
    ${cmd} 2>&1 | tee -a $out/logs/git.log || echo "Command failed with code $?" | tee -a $out/logs/git.log
  `).join('\n  ')}
  
  # Copy any results back
  cp -r .git $out/ 2>/dev/null || true
  find . -name "*.log" -exec cp {} $out/logs/ \\; 2>/dev/null || true
''`;

    const nixExprPath = join(sessionDir, 'git-execution.nix');
    await writeFile(nixExprPath, nixExpr);

    try {
      const { stdout, stderr } = await execPromise(
        `nix-build ${nixExprPath} --no-out-link --option sandbox true`,
        { cwd: sessionDir }
      );

      const resultPath = stdout.trim();
      const logContent = await this.readSandboxLogs(resultPath);

      return {
        success: true,
        exitCode: 0,
        stdout: logContent.stdout || '',
        stderr: logContent.stderr || '',
        logPath: join(resultPath, 'logs'),
        resultPath
      };
    } catch (error: any) {
      return {
        success: false,
        exitCode: error.code || 1,
        stdout: '',
        stderr: error.message,
        logPath: sessionDir,
        resultPath: sessionDir
      };
    }
  }

  /**
   * Execute external tools in Nix sandbox
   */
  async executeToolSandboxed(tool: string, args: string[], env: Record<string, string> = {}): Promise<NixSandboxResult> {
    if (!this.isNixAvailable) {
      return this.fallbackToolExecution(tool, args, env);
    }

    const sessionDir = join(this.deeboRoot, 'memory-bank', 'nix-sandbox', `tool-${Date.now()}`);
    await mkdir(sessionDir, { recursive: true });

    const envVars = Object.entries(env)
      .map(([k, v]) => `export ${k}='${v}'`)
      .join('\n  ');

    const nixExpr = `
{ pkgs ? import <nixpkgs> {} }:

pkgs.runCommand "tool-sandbox" {
  buildInputs = with pkgs; [ ${tool} ];
  __noChroot = false;
  allowSubstitutes = false;
} ''
  mkdir -p $out/logs $out/results
  
  ${envVars}
  
  ${tool} ${args.join(' ')} 2>&1 | tee $out/logs/execution.log
  echo $? > $out/results/exit_code
''`;

    const nixExprPath = join(sessionDir, 'tool-execution.nix');
    await writeFile(nixExprPath, nixExpr);

    try {
      const { stdout, stderr } = await execPromise(
        `nix-build ${nixExprPath} --no-out-link --option sandbox true`,
        { cwd: sessionDir }
      );

      const resultPath = stdout.trim();
      const logContent = await this.readSandboxLogs(resultPath);
      const exitCodeFile = join(resultPath, 'results', 'exit_code');
      let exitCode = 0;
      
      try {
        exitCode = parseInt(await readFile(exitCodeFile, 'utf8'));
      } catch {
        // Use default exit code if file doesn't exist
      }

      return {
        success: exitCode === 0,
        exitCode,
        stdout: logContent.stdout || '',
        stderr: logContent.stderr || '',
        logPath: join(resultPath, 'logs'),
        resultPath
      };
    } catch (error: any) {
      return {
        success: false,
        exitCode: error.code || 1,
        stdout: '',
        stderr: error.message,
        logPath: sessionDir,
        resultPath: sessionDir
      };
    }
  }

  private generateNixExpression(config: NixSandboxConfig): string {
    const language = config.language || 'bash';
    const allowedPaths = config.allowedPaths || [];
    
    const buildInputs = this.getBuildInputsForLanguage(language);
    const execution = this.getExecutionForLanguage(language, config.code);
    
    return `
{ pkgs ? import <nixpkgs> {} }:

pkgs.runCommand "${config.name}" {
  buildInputs = with pkgs; [ ${buildInputs.join(' ')} ];
  __noChroot = false;
  allowSubstitutes = false;
  ${config.env ? Object.entries(config.env).map(([k, v]) => `${k} = "${v}";`).join('\n  ') : ''}
} ''
  mkdir -p $out/logs $out/results
  
  # Create isolated environment
  ${allowedPaths.map(path => `ln -s ${path} ./`).join('\n  ')}
  
  # Execute code in restricted environment
  ${execution}
  
  # Capture exit code
  echo $? > $out/results/exit_code
  
  # Capture any output files
  find . -maxdepth 1 -type f -exec cp {} $out/results/ \\; 2>/dev/null || true
''`;
  }

  private getBuildInputsForLanguage(language: string): string[] {
    switch (language) {
      case 'python':
        return ['bash', 'coreutils', 'python3'];
      case 'nodejs':
        return ['bash', 'coreutils', 'nodejs'];
      case 'typescript':
        return ['bash', 'coreutils', 'nodejs', 'typescript'];
      default:
        return ['bash', 'coreutils', 'findutils', 'gnugrep', 'gnused'];
    }
  }

  private getExecutionForLanguage(language: string, code: string): string {
    const escapedCode = code.replace(/'/g, `'"'"'`);
    
    switch (language) {
      case 'python':
        return `
  echo '${escapedCode}' > script.py
  python3 script.py 2>&1 | tee $out/logs/execution.log`;
      case 'nodejs':
        return `
  echo '${escapedCode}' > script.js
  node script.js 2>&1 | tee $out/logs/execution.log`;
      case 'typescript':
        return `
  echo '${escapedCode}' > script.ts
  npx tsc script.ts && node script.js 2>&1 | tee $out/logs/execution.log`;
      default:
        return `
  echo '${escapedCode}' > script.sh
  chmod +x script.sh
  ./script.sh 2>&1 | tee $out/logs/execution.log`;
    }
  }

  private async readSandboxLogs(resultPath: string): Promise<{ stdout?: string; stderr?: string }> {
    try {
      const logPath = join(resultPath, 'logs', 'execution.log');
      const content = await readFile(logPath, 'utf8');
      return { stdout: content };
    } catch {
      return {};
    }
  }

  // Fallback methods for when Nix is not available
  private async fallbackExecution(config: NixSandboxConfig): Promise<NixSandboxResult> {
    console.warn('Using fallback execution without Nix sandbox');
    // Implement basic execution without Nix for compatibility
    const sessionDir = join(this.deeboRoot, 'memory-bank', 'fallback', config.name);
    await mkdir(sessionDir, { recursive: true });
    
    return {
      success: false,
      exitCode: 1,
      stdout: '',
      stderr: 'Nix sandbox not available',
      logPath: sessionDir,
      resultPath: sessionDir
    };
  }

  private async fallbackGitExecution(repoPath: string, commands: string[]): Promise<NixSandboxResult> {
    console.warn('Using fallback Git execution without Nix sandbox');
    // Implement basic git execution without Nix for compatibility
    return {
      success: false,
      exitCode: 1,
      stdout: '',
      stderr: 'Nix sandbox not available for Git operations',
      logPath: repoPath,
      resultPath: repoPath
    };
  }

  private async fallbackToolExecution(tool: string, args: string[], env: Record<string, string>): Promise<NixSandboxResult> {
    console.warn('Using fallback tool execution without Nix sandbox');
    // Implement basic tool execution without Nix for compatibility
    return {
      success: false,
      exitCode: 1,
      stdout: '',
      stderr: 'Nix sandbox not available for tool execution',
      logPath: '',
      resultPath: ''
    };
  }
}

// Create singleton instance factory function
export function createNixSandbox(deeboRoot: string): NixSandboxExecutor {
  return new NixSandboxExecutor(deeboRoot);
}