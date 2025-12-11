import os
import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, render_template, request, jsonify
from datetime import datetime

app = Flask(__name__)

def get_db_connection():
    """Create database connection using DATABASE_URL"""
    conn = psycopg2.connect(
        os.environ["DATABASE_URL"],
        cursor_factory=RealDictCursor
    )
    return conn

def get_locales():
    """Fetch available locales from database"""
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT locale_code, locale_name FROM locales ORDER BY locale_code")
    locales = cur.fetchall()
    cur.close()
    conn.close()
    return locales

def generate_users(locale, seed, batch_index, batch_size=10):
    """Call stored procedure to generate fake users"""
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    cur.execute("""
        SELECT * FROM generate_fake_users(%s, %s, %s, %s)
    """, (locale, seed, batch_index, batch_size))
    
    users = cur.fetchall()
    cur.close()
    conn.close()
    
    return users

@app.route('/')
def index():
    """Render main page"""
    locales = get_locales()
    return render_template('index.html', locales=locales)

@app.route('/api/generate', methods=['POST'])
def api_generate():
    """API endpoint to generate users"""
    try:
        data = request.json
        locale = data.get('locale', 'en_US')
        seed = int(data.get('seed', 12345))
        batch_index = int(data.get('batch_index', 0))
        batch_size = int(data.get('batch_size', 10))
        
        # Validate inputs
        if batch_size < 1 or batch_size > 100:
            return jsonify({'error': 'Batch size must be between 1 and 100'}), 400
        
        if seed < 0 or seed > 2147483647:
            return jsonify({'error': 'Seed must be between 0 and 2147483647'}), 400
        
        users = generate_users(locale, seed, batch_index, batch_size)
        
        # Format coordinates to reasonable precision
        for user in users:
            user['latitude'] = round(user['latitude'], 6)
            user['longitude'] = round(user['longitude'], 6)
        
        return jsonify({
            'users': users,
            'locale': locale,
            'seed': seed,
            'batch_index': batch_index,
            'batch_size': batch_size,
            'timestamp': datetime.now().isoformat()
        })
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return jsonify({'status': 'healthy', 'database': 'connected'})
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

if __name__ == '__main__':

    app.run(debug=True, host='0.0.0.0', port=5000)


