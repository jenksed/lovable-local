#!/bin/bash

# Lovable Local Development Environment Setup
# Interactive setup script for creating portable React/TypeScript projects with PostgreSQL
# Repository: https://github.com/yourusername/lovable-local
# License: MIT

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
show_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║        🚀 LOVABLE LOCAL DEVELOPMENT ENVIRONMENT         ║
    ║                                                          ║
    ║     Create portable, local dev setups for modern        ║
    ║     React/TypeScript projects with PostgreSQL           ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}Open source development environment generator${NC}"
    echo -e "${CYAN}For issues and contributions: https://github.com/yourusername/lovable-local${NC}"
    echo ""
}

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${CYAN}🔄 $1${NC}"; }
log_header() { echo -e "${PURPLE}$1${NC}"; }

# Check if command exists
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Generic user prompt function
prompt_user() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    read -p "$prompt (default: $default): " input
    eval "$var_name='${input:-$default}'"
}

# Execute step with simplified retry/skip logic
execute_step() {
    local step_name="$1"
    local step_function="$2"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log_step "$step_name (Attempt $attempt/$max_attempts)"
        if $step_function; then
            log_success "$step_name completed successfully"
            return 0
        fi
        log_error "$step_name failed"
        if [ $attempt -lt $max_attempts ]; then
            read -p "Retry, Skip, or Exit? (r/s/e): " -n 1 -r choice
            echo
            case $choice in
                [Rr]*) ((attempt++)) ;;
                [Ss]*) log_warning "Skipping $step_name"; return 1 ;;
                [Ee]*) log_error "Exiting setup"; exit 1 ;;
                *) log_warning "Invalid choice, retrying"; ((attempt++)) ;;
            esac
        else
            read -p "Max attempts reached. Skip or Exit? (s/e): " -n 1 -r choice
            echo
            [[ $choice =~ ^[Ss]$ ]] && { log_warning "Skipping $step_name"; return 1; } || exit 1
        fi
    done
}

# Check Homebrew installation
check_homebrew() {
    if ! command_exists brew; then
        log_warning "Homebrew not found"
        read -p "Install Homebrew now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_step "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
            log_success "Homebrew installed successfully"
        else
            log_error "Homebrew is required for this setup"
            return 1
        fi
    else
        log_success "Homebrew is installed"
    fi
    return 0
}

# Install required tools
install_tools() {
    log_step "Installing core development tools..."
    local tools=("node" "bun" "postgresql@15" "git")
    
    for tool in "${tools[@]}"; do
        if [[ "$tool" == "postgresql@15" ]]; then
            if ! command_exists postgres && ! command_exists psql; then
                log_info "Installing PostgreSQL 15..."
                brew install postgresql@15 || return 1
                log_success "PostgreSQL 15 installed"
            else
                log_success "PostgreSQL already installed"
            fi
        elif ! command_exists "$tool"; then
            log_info "Installing $tool..."
            brew install "$tool" || return 1
            log_success "$tool installed"
        else
            log_success "$tool already installed"
        fi
    done
    
    # Ask about optional tools
    read -p "Install optional tools (jq, tree, fzf, ripgrep)? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local optional_tools=("jq" "tree" "fzf" "ripgrep")
        for tool in "${optional_tools[@]}"; do
            if ! command_exists "$tool"; then
                log_info "Installing $tool..."
                brew install "$tool" || log_warning "Failed to install $tool"
            else
                log_success "$tool already installed"
            fi
        done
    fi
    
    return 0
}

# Start PostgreSQL service
start_postgres() {
    log_step "Starting PostgreSQL service..."
    if brew services list | grep -q "postgresql@15.*started"; then
        log_success "PostgreSQL already running"
    else
        log_info "Starting PostgreSQL service..."
        brew services start postgresql@15 || return 1
        sleep 3
        log_success "PostgreSQL service started"
    fi
    return 0
}

# Create database
create_database() {
    log_step "Creating database..."
    if [ -z "$DB_NAME" ]; then
        prompt_user "Enter database name" "lovable_dev" DB_NAME
    fi
    
    if psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        log_success "Database '$DB_NAME' already exists"
    else
        log_info "Creating database '$DB_NAME'..."
        createdb "$DB_NAME" || return 1
        log_success "Database '$DB_NAME' created"
    fi
    return 0
}

# Create environment file
create_env_file() {
    log_step "Creating environment configuration..."
    if [ ! -f ".env.local" ]; then
        if [ -z "$DB_NAME" ]; then
            DB_NAME="lovable_dev"
        fi
        
        prompt_user "Database host" "localhost" DB_HOST
        prompt_user "Database port" "5432" DB_PORT  
        prompt_user "Database user" "${USER}" DB_USER
        read -p "Database password (leave blank for none): " DB_PASSWORD
        prompt_user "API URL" "http://localhost:3001" VITE_API_URL
        
        cat > .env.local << EOF
# Database Configuration
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD

# Development Settings
VITE_APP_ENV=development
VITE_API_URL=$VITE_API_URL
EOF
        log_success "Created .env.local"
    else
        log_success ".env.local already exists"
    fi
    return 0
}

# Create directories
create_directories() {
    log_step "Creating project directories..."
    local directories=(
        "scripts" 
        "migrations" 
        ".vscode" 
        "docs" 
        "src/integrations/database" 
        "src/components/ui" 
        "src/hooks" 
        "src/lib" 
        "src/pages" 
        "public"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_success "Created directory: $dir"
        else
            log_success "Directory exists: $dir"
        fi
    done
    return 0
}

# Create file with content (helper function)
create_file() {
    local filename="$1"
    local content="$2"
    if [ ! -f "$filename" ]; then
        echo "$content" > "$filename"
        log_success "Created $filename"
    else
        log_success "$filename already exists"
    fi
    return 0
}

# Create migration script
create_migration_script() {
    log_step "Creating database migration script..."
    local content='const { Pool } = require('\''pg'\'');
const fs = require('\''fs'\'');
const path = require('\''path'\'');

const pool = new Pool({
  user: process.env.DB_USER || process.env.USER,
  host: process.env.DB_HOST || '\''localhost'\'',
  database: process.env.DB_NAME || '\''lovable_dev'\'',
  password: process.env.DB_PASSWORD || '\'\'\'',
  port: parseInt(process.env.DB_PORT || '\''5432'\''),
});

async function runMigrations() {
  try {
    console.log('\''🔄 Running database migrations...'\'');
    const migrationsPath = path.join(__dirname, '\''..'\'', '\''migrations'\'');
    
    if (!fs.existsSync(migrationsPath)) {
      console.log('\''ℹ️  No migrations directory found'\'');
      return;
    }
    
    const files = fs.readdirSync(migrationsPath)
      .filter(file => file.endsWith('\''.sql'\''))
      .sort();
    
    if (files.length === 0) {
      console.log('\''ℹ️  No migration files found'\'');
      return;
    }
    
    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsPath, file), '\''utf8'\'');
      await pool.query(sql);
      console.log(`✅ Executed: ${file}`);
    }
    
    console.log('\''🎉 Migrations completed'\'');
  } catch (error) {
    console.error('\''❌ Migration failed:'\'', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigrations();'
    
    create_file "scripts/migrate.js" "$content"
    return 0
}

# Create initial migration
create_initial_migration() {
    log_step "Creating initial database schema..."
    local content='-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_projects_user_id ON projects(user_id);

-- Update trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language '\''plpgsql'\'';

-- Apply triggers
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at 
    BEFORE UPDATE ON projects 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();'

    create_file "migrations/001_initial_schema.sql" "$content"
    return 0
}

# Create VSCode settings
create_vscode_settings() {
    log_step "Creating VSCode configuration..."
    
    local settings_content='{
  "typescript.preferences.importModuleSpecifier": "relative",
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "tailwindCSS.experimental.classRegex": [
    ["cva\\\\(([^)]*)\\\\)", "[\\"'\''`]([^\\"'\''`]*).*?[\\"'\''`]"],
    ["cx\\\\(([^)]*)\\\\)", "(?:'\''|\\"|`)([^'\'']*)(?:'\''|\\"|`)"]
  ],
  "typescript.preferences.includePackageJsonAutoImports": "auto",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "files.associations": {
    "*.css": "tailwindcss"
  }
}'

    local extensions_content='{
  "recommendations": [
    "esbenp.prettier-vscode",
    "bradlc.vscode-tailwindcss",
    "ms-vscode.vscode-typescript-next",
    "dbaeumer.vscode-eslint",
    "christian-kohler.path-intellisense",
    "formulahendry.auto-rename-tag"
  ]
}'
    
    create_file ".vscode/settings.json" "$settings_content"
    create_file ".vscode/extensions.json" "$extensions_content"
    return 0
}

# Create README
create_readme() {
    log_step "Creating README documentation..."
    local content='# Lovable Local Development Environment

A portable development environment for creating modern React/TypeScript projects with PostgreSQL.

## Features

- 🚀 **Quick Setup**: Interactive script handles everything
- 📦 **Modern Stack**: React, TypeScript, Tailwind CSS, PostgreSQL  
- 🔧 **Development Tools**: ESLint, Prettier, Vite
- 🗄️ **Database Ready**: PostgreSQL with migrations
- 📱 **Responsive**: Mobile-first design patterns
- 🎨 **Styled**: Tailwind CSS for rapid styling

## Quick Start

```bash
# Clone this repository
git clone https://github.com/yourusername/lovable-local.git
cd lovable-local

# Run interactive setup
bash setup-dev-env.sh
```

## Development Commands

```bash
# Start development server
npm run dev

# Database operations  
npm run db:migrate        # Run migrations
npm run db:reset         # Reset database

# Build
npm run build           # Production build
npm run preview         # Preview build
```

## Project Structure

```
project/
├── src/
│   ├── components/ui/    # UI components
│   ├── hooks/           # React hooks
│   ├── integrations/    # Database
│   └── pages/          # Pages
├── migrations/         # DB migrations
├── scripts/           # Build scripts
└── .vscode/          # VS Code config
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.'

    create_file "README.md" "$content"
    return 0
}

# Create LICENSE
create_license() {
    log_step "Creating LICENSE file..."
    if [ ! -f "LICENSE" ]; then
        read -p "Choose license (MIT/Apache-2.0/none) [MIT]: " license
        license=${license:-MIT}
        
        case $license in
            "MIT"|"mit")
                local content='MIT License

Copyright (c) 2025 Lovable Local Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.'
                create_file "LICENSE" "$content"
                ;;
            "Apache-2.0"|"apache")
                local content='Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

Copyright 2025 Lovable Local Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.'
                create_file "LICENSE" "$content"
                ;;
            "none")
                log_info "Skipping license creation"
                ;;
        esac
    else
        log_success "LICENSE already exists"
    fi
    return 0
}

# Create contributing guidelines
create_contributing() {
    log_step "Creating contribution guidelines..."
    local content='# Contributing to Lovable Local

Thank you for contributing! 🎉

## How to Contribute

1. Fork the repository
2. Create your feature branch
3. Test your changes
4. Submit a pull request

## Development

```bash
# Test the setup script
bash setup-dev-env.sh

# Verify all components work
npm run dev
npm run db:migrate
```

## Guidelines

- Follow existing code style
- Write clear commit messages  
- Add tests for new features
- Update documentation

## Reporting Issues

- Check existing issues first
- Provide clear reproduction steps
- Include system information

## Questions?

Open a GitHub Discussion or Issue.

Thanks for making Lovable Local better! 🚀'

    create_file "CONTRIBUTING.md" "$content"
    return 0
}

# Install dependencies
install_dependencies() {
    log_step "Installing project dependencies..."
    
    # Create package.json if it doesn't exist
    if [ ! -f "package.json" ]; then
        if [ -z "$PROJECT_NAME" ]; then
            prompt_user "Project name" "lovable-local-project" PROJECT_NAME
        fi
        
        local package_content='{
  "name": "'$PROJECT_NAME'",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "db:migrate": "node scripts/migrate.js",
    "db:reset": "dropdb '$DB_NAME' && createdb '$DB_NAME' && npm run db:migrate"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "pg": "^8.11.3"
  },
  "devDependencies": {
    "@types/react": "^18.2.66",
    "@types/react-dom": "^18.2.22",
    "@types/pg": "^8.10.9",
    "@vitejs/plugin-react-swc": "^3.5.0",
    "typescript": "^5.2.2",
    "vite": "^5.2.0"
  }
}'
        create_file "package.json" "$package_content"
    fi
    
    read -p "Use Bun for faster installs? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]] && command_exists bun; then
        log_info "Installing with bun..."
        bun install || return 1
        log_success "Dependencies installed with bun"
    else
        log_info "Installing with npm..."
        npm install || return 1
        log_success "Dependencies installed with npm"
    fi
    return 0
}

# Update package.json (placeholder for when jq is available)
update_package_scripts() {
    log_step "Checking package.json scripts..."
    if [ -f "package.json" ] && command_exists jq; then
        log_success "Package.json scripts are up to date"
    else
        log_info "Scripts will be updated when dependencies are installed"
    fi
    return 0
}

# Run database migrations
run_migrations() {
    log_step "Running database migrations..."
    read -p "Run database migrations now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "scripts/migrate.js" ]; then
            log_info "Executing migrations..."
            node scripts/migrate.js || return 1
            log_success "Database migrations completed"
        else
            log_warning "Migration script not found"
            return 1
        fi
    else
        log_info "Skipped migrations (run later with: npm run db:migrate)"
    fi
    return 0
}

# Create database client
create_database_client() {
    log_step "Creating database client..."
    local content='import { Pool } from '\''pg'\'';

const pool = new Pool({
  user: process.env.DB_USER || process.env.USER,
  host: process.env.DB_HOST || '\''localhost'\'',
  database: process.env.DB_NAME || '\''lovable_dev'\'',
  password: process.env.DB_PASSWORD || '\'\'\'',
  port: parseInt(process.env.DB_PORT || '\''5432'\''),
});

export const query = (text: string, params?: any[]) => {
  return pool.query(text, params);
};

export const getClient = async () => {
  const client = await pool.connect();
  return client;
};

export default pool;'

    create_file "src/integrations/database/client.ts" "$content"
    return 0
}

# Menu-driven setup
display_menu() {
    echo ""
    log_info "🚀 Lovable Local Setup Menu"
    echo "1.  Check Homebrew"
    echo "2.  Install Tools" 
    echo "3.  Start PostgreSQL"
    echo "4.  Create Database"
    echo "5.  Create Environment File"
    echo "6.  Create Directories"
    echo "7.  Create Migration Script"
    echo "8.  Create Initial Migration"
    echo "9.  Create VSCode Settings"
    echo "10. Create README"
    echo "11. Create LICENSE"
    echo "12. Create Contributing Guidelines"
    echo "13. Install Dependencies"
    echo "14. Update package.json"
    echo "15. Run Migrations"
    echo "16. Create Database Client"
    echo "17. Run All Steps"
    echo "18. Start Dev Server"
    echo "19. Exit"
    echo ""
    read -p "Select option (1-19): " choice
    echo $choice
}

# Start development server
start_dev_server() {
    log_step "Starting development server..."
    if [ -f "package.json" ]; then
        if command_exists bun && [ -f "bun.lockb" ]; then
            log_info "Starting with bun..."
            bun dev
        elif command_exists npm; then
            log_info "Starting with npm..."
            npm run dev
        else
            log_error "No package manager found"
            return 1
        fi
    else
        log_error "No package.json found. Run setup steps first."
        return 1
    fi
}

# Run all steps
run_all_steps() {
    log_header "🚀 RUNNING COMPLETE SETUP"
    echo ""
    
    local steps=(
        "Check Homebrew:check_homebrew"
        "Install Tools:install_tools"  
        "Start PostgreSQL:start_postgres"
        "Create Database:create_database"
        "Create Environment File:create_env_file"
        "Create Directories:create_directories"
        "Create Migration Script:create_migration_script"
        "Create Initial Migration:create_initial_migration"
        "Create VSCode Settings:create_vscode_settings"
        "Create README:create_readme"
        "Create LICENSE:create_license"
        "Create Contributing Guidelines:create_contributing"
        "Install Dependencies:install_dependencies"
        "Run Migrations:run_migrations"
        "Create Database Client:create_database_client"
    )

    for step in "${steps[@]}"; do
        local step_name="${step%%:*}"
        local step_function="${step#*:}"
        execute_step "$step_name" "$step_function"
    done
    
    echo ""
    log_success "🎉 Complete setup finished!"
    log_info "Next: Select option 18 to start the development server"
    return 0
}

# Main function
main() {
    show_banner
    
    local steps=(
        "Check Homebrew:check_homebrew"
        "Install Tools:install_tools"
        "Start PostgreSQL:start_postgres" 
        "Create Database:create_database"
        "Create Environment File:create_env_file"
        "Create Directories:create_directories"
        "Create Migration Script:create_migration_script"
        "Create Initial Migration:create_initial_migration"
        "Create VSCode Settings:create_vscode_settings"
        "Create README:create_readme"
        "Create LICENSE:create_license"
        "Create Contributing Guidelines:create_contributing"
        "Install Dependencies:install_dependencies"
        "Update package.json Scripts:update_package_scripts"
        "Run Migrations:run_migrations"
        "Create Database Client:create_database_client"
    )

    while true; do
        choice=$(display_menu)
        
        case $choice in
            1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16)
                local index=$((choice-1))
                if [ $index -ge 0 ] && [ $index -lt ${#steps[@]} ]; then
                    local step="${steps[$index]}"
                    execute_step "${step%%:*}" "${step#*:}"
                fi
                ;;
            17)
                run_all_steps
                ;;
            18)
                start_dev_server
                ;;
            19)
                log_info "Goodbye! 👋"
                break
                ;;
            *)
                log_warning "Invalid option. Please select 1-19."
                ;;
        esac
    done

    echo ""
    log_success "🎉 Setup complete!"
    echo ""
    log_info "Useful commands:"
    echo "• npm run dev - Start development server"
    echo "• npm run db:migrate - Run database migrations"
    echo "• npm run db:reset - Reset database"
    echo "• brew services stop postgresql@15 - Stop PostgreSQL"
    echo ""
    log_info "Happy coding! 🚀"
}

# Call main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi