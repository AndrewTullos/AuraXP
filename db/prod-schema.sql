-- Drop existing objects to avoid conflicts (optional, comment out if not needed)
DROP TABLE IF EXISTS user_trophies CASCADE;
DROP TABLE IF EXISTS trophies CASCADE;
DROP TABLE IF EXISTS activity_log CASCADE;
DROP TABLE IF EXISTS user_goals CASCADE;
DROP TABLE IF EXISTS predefined_goals CASCADE;
DROP TYPE IF EXISTS goal_recurrence CASCADE;
DROP TYPE IF EXISTS goal_type CASCADE;
DROP TABLE IF EXISTS goal_categories CASCADE;
DROP TABLE IF EXISTS level_thresholds CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP FUNCTION IF EXISTS trigger_set_timestamp CASCADE;

-- Create the trigger function for updating timestamps
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the users table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    xp_points INTEGER DEFAULT 0 NOT NULL,
    current_level INTEGER DEFAULT 1 NOT NULL,
    profile_picture_url VARCHAR(512),
    timezone VARCHAR(100) DEFAULT 'UTC',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create trigger for users table
CREATE TRIGGER set_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();

-- Create index on users email
CREATE INDEX idx_users_email ON users(email);

-- Create the goal_categories table
CREATE TABLE goal_categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    icon_name VARCHAR(50)
);

-- Insert data into goal_categories
INSERT INTO goal_categories (category_name, description) VALUES
    ('Physical Health', 'Goals related to body fitness, nutrition, and sleep.'),
    ('Mental Wellness', 'Goals for mindfulness, stress reduction, and emotional balance.'),
    ('Personal Growth', 'Goals focused on learning, skill development, and creativity.'),
    ('Social Connection', 'Goals to foster relationships and community engagement.'),
    ('Productivity & Work', 'Goals for managing tasks, focus, and professional development.'),
    ('Financial Wellness', 'Goals related to managing money, saving, and financial literacy.'),
    ('Spiritual & Values', 'Goals connecting to personal beliefs, values, and inner peace.'),
    ('Recreation & Hobbies', 'Goals for fun, relaxation, and enjoying leisure activities.');

-- Create ENUM types
CREATE TYPE goal_type AS ENUM ('TIME_BASED', 'COUNT_BASED', 'COMPLETION_BASED');
CREATE TYPE goal_recurrence AS ENUM ('DAILY', 'WEEKLY', 'BI_WEEKLY', 'MONTHLY', 'ONE_TIME');

-- Create the predefined_goals table
CREATE TABLE predefined_goals (
    predefined_goal_id SERIAL PRIMARY KEY,
    goal_name VARCHAR(255) NOT NULL,
    description TEXT,
    category_id INTEGER REFERENCES goal_categories(category_id),
    default_xp_value INTEGER NOT NULL CHECK (default_xp_value > 0),
    type goal_type NOT NULL,
    default_target_value NUMERIC,
    default_target_unit VARCHAR(50),
    default_recurrence goal_recurrence DEFAULT 'DAILY',
    estimated_duration_minutes INTEGER,
    icon_name VARCHAR(50),
    is_system_goal BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index on predefined_goals
CREATE INDEX idx_predefined_goals_category_id ON predefined_goals(category_id);

-- Create the user_goals table
CREATE TABLE user_goals (
    user_goal_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    predefined_goal_id INTEGER REFERENCES predefined_goals(predefined_goal_id) ON DELETE SET NULL,
    custom_goal_name VARCHAR(255),
    custom_description TEXT,
    xp_value_override INTEGER CHECK (xp_value_override > 0),
    type_override goal_type,
    target_value_override NUMERIC,
    target_unit_override VARCHAR(50),
    recurrence_override goal_recurrence,
    estimated_duration_minutes_override INTEGER,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    current_streak INTEGER DEFAULT 0 NOT NULL,
    longest_streak INTEGER DEFAULT 0 NOT NULL,
    last_completed_at TIMESTAMP WITH TIME ZONE,
    next_due_date DATE,
    reminder_time TIME WITHOUT TIME ZONE,
    start_date DATE DEFAULT CURRENT_DATE,
    end_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_goal_origin CHECK (predefined_goal_id IS NOT NULL OR custom_goal_name IS NOT NULL)
);

-- Create trigger for user_goals table
CREATE TRIGGER set_user_goals_updated_at
    BEFORE UPDATE ON user_goals
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();

-- Create indexes on user_goals
CREATE INDEX idx_user_goals_user_id ON user_goals(user_id);
CREATE INDEX idx_user_goals_predefined_goal_id ON user_goals(predefined_goal_id);
CREATE INDEX idx_user_goals_is_active ON user_goals(user_id, is_active);
CREATE INDEX idx_user_goals_next_due_date ON user_goals(user_id, next_due_date);

-- Create the activity_log table
CREATE TABLE activity_log (
    activity_id SERIAL PRIMARY KEY,
    user_goal_id INTEGER NOT NULL REFERENCES user_goals(user_goal_id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    value_achieved NUMERIC,
    xp_earned INTEGER NOT NULL,
    notes TEXT,
    UNIQUE (user_goal_id, logged_at)
);

-- Create indexes on activity_log
CREATE INDEX idx_activity_log_user_goal_id ON activity_log(user_goal_id);
CREATE INDEX idx_activity_log_user_id_logged_at ON activity_log(user_id, logged_at DESC);

-- Create the trophies table
CREATE TABLE trophies (
    trophy_id SERIAL PRIMARY KEY,
    trophy_name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    icon_url VARCHAR(512),
    unlock_criteria_description TEXT,
    unlock_logic_key VARCHAR(100) UNIQUE,
    xp_bonus INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create the user_trophies table
CREATE TABLE user_trophies (
    user_trophy_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    trophy_id INTEGER NOT NULL REFERENCES trophies(trophy_id) ON DELETE CASCADE,
    unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, trophy_id)
);

-- Create indexes on user_trophies
CREATE INDEX idx_user_trophies_user_id ON user_trophies(user_id);
CREATE INDEX idx_user_trophies_trophy_id ON user_trophies(trophy_id);

-- Create the level_thresholds table
CREATE TABLE level_thresholds (
    level_number INTEGER PRIMARY KEY CHECK (level_number > 0),
    xp_required INTEGER UNIQUE NOT NULL CHECK (xp_required >= 0),
    level_title VARCHAR(100),
    unlock_message TEXT
);

-- Insert data into level_thresholds
INSERT INTO level_thresholds (level_number, xp_required, level_title) VALUES
    (1, 0, 'Aura Brainrot Bot'),
    (2, 100, 'Aura Apprentice'),
    (3, 250, 'Aura Adept'),
    (4, 500, 'Aura Guardian'),
    (5, 1000, 'Aura Master');