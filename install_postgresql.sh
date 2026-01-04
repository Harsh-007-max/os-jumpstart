#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared_functions.sh"

PG_CONF="/var/lib/pgsql/data/pg_hba.conf"
PG_DATA="/var/lib/pgsql/data/postgresql.conf"

setup_postgresql() {
    print_title "Configuring PostgreSQL"

    # --- STEP 1: INITIALIZATION (Run Only Once) ---
    if [ ! -f "$PG_DATA" ]; then
        info "Initializing database engine..."
        if sudo /usr/bin/postgresql-setup --initdb --unit postgresql; then
            success "Database initialized."
        else
            error "Failed to initialize database."
            return 1
        fi
    else
        info "Database engine already initialized."
    fi

    # --- STEP 2: SERVICE START (Always Run) ---
    # We run this OUTSIDE the init check to ensure the service is actually ON.
    info "Ensuring PostgreSQL service is running..."
    if ! sudo systemctl enable --now postgresql; then
        error "Failed to enable PostgreSQL."
        return 1
    fi

    # Wait for socket to be ready
    until sudo -u postgres psql -c '\q' &>/dev/null; do
        sleep 1
    done
    success "PostgreSQL is active and accepting connections."

    # --- STEP 3: USER & PASSWORD (Docker Style) ---
    info "Configuring 'postgres' user..."

    # We set the password every time. It's safe and ensures it matches your expectation.
    if sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';" &>/dev/null; then
        success "Password for 'postgres' set to 'postgres'."
    else
        error "Failed to set password."
        return 1
    fi

    # --- STEP 4: AUTH CONFIG (pg_hba.conf) ---
    if [ -f "$PG_CONF" ]; then
        # Check if we actually need to change anything to avoid restarting unnecessarily
        if grep -q "ident" "$PG_CONF" || grep -q "peer" "$PG_CONF"; then
            info "Updating authentication methods to scram-sha-256..."

            sudo cp "$PG_CONF" "$PG_CONF.bak"
            sudo sed -i 's/ident/scram-sha-256/g' "$PG_CONF"
            sudo sed -i 's/peer/scram-sha-256/g' "$PG_CONF"

            success "Updated pg_hba.conf."

            info "Restarting PostgreSQL to apply changes..."
            sudo systemctl restart postgresql
        else
            info "Authentication already configured correctly."
        fi
    else
        error "Could not find $PG_CONF"
        return 1
    fi

    success "PostgreSQL Setup Complete! Login: psql -U postgres -h localhost"
}

install_postgresql() {
    print_title "Installing PostgreSQL"

    if rpm -q postgresql-server &> /dev/null; then
        info "PostgreSQL packages already installed."
    else
        info "Installing PostgreSQL..."
        if sudo dnf install -y postgresql-server postgresql-contrib; then
            success "PostgreSQL installed successfully."
        else
            error "Failed to install PostgreSQL."
            return 1
        fi
    fi

    # CALL THE SETUP FUNCTION HERE
    setup_postgresql
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_postgresql
fi
