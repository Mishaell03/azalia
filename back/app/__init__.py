from flask import Flask, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import os

db = SQLAlchemy()

def create_app():
    app = Flask(__name__)
    
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')
    
    base_dir = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
    db_path = os.path.join(base_dir, 'flower_shop.db')
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
    
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    
    db.init_app(app)
    CORS(app)
    
    @app.route('/api/img/<path:filename>')
    def serve_image(filename):
        img_dir = os.path.join(base_dir, 'img')
        return send_from_directory(img_dir, filename)
    
    from app.routes.plants import bp as plants_bp
    from app.routes.categories import bp as categories_bp
    from app.routes.employees import bp as employees_bp
    from app.routes.auth import bp as auth_bp
    from app.routes.cart import bp as cart_bp
    
    app.register_blueprint(plants_bp)
    app.register_blueprint(categories_bp)
    app.register_blueprint(employees_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(cart_bp)
    
    return app