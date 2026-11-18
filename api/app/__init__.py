import click
from flask import Flask, jsonify
from sqlalchemy import inspect
from werkzeug.exceptions import HTTPException

from .config import Config
from .extensions import bcrypt, db, jwt, migrate


def create_app(config_object=Config) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_object)
    app.json.ensure_ascii = False  # acentos legíveis no JSON

    db.init_app(app)
    bcrypt.init_app(app)
    jwt.init_app(app)

    from . import models  # noqa: F401  (registra as tabelas antes do migrate)

    migrate.init_app(app, db)

    from .routes import BLUEPRINTS

    for bp in BLUEPRINTS:
        app.register_blueprint(bp)

    _registrar_erros(app)
    _registrar_cli(app)

    @app.get("/")
    def saude():
        return jsonify({"app": "ONG Mais API", "status": "ok"})

    with app.app_context():
        if _usa_sqlite(app) and app.config.get("AUTO_CREATE_TABLES", True):
            # Desenvolvimento/testes: cria as tabelas direto do modelo
            db.create_all()
        # MySQL (produção): tabelas vêm das migrações -> `flask db upgrade`
        if app.config.get("AUTO_SEED") and inspect(db.engine).has_table("tb_usuarios"):
            from .seed import semear

            semear()

    return app


def _usa_sqlite(app: Flask) -> bool:
    return app.config["SQLALCHEMY_DATABASE_URI"].startswith("sqlite")


def _registrar_erros(app: Flask):
    @app.errorhandler(HTTPException)
    def http_error(e):
        return jsonify({"erro": e.description}), e.code

    @app.errorhandler(Exception)
    def generic_error(e):
        app.logger.exception(e)
        db.session.rollback()
        return jsonify({"erro": "Erro interno no servidor.", "detalhe": str(e)}), 500

    @jwt.unauthorized_loader
    def sem_token(msg):
        return jsonify({"erro": "Token ausente. Faça login novamente."}), 401

    @jwt.invalid_token_loader
    def token_invalido(msg):
        return jsonify({"erro": "Token inválido. Faça login novamente."}), 401

    @jwt.expired_token_loader
    def token_expirado(h, p):
        return jsonify({"erro": "Sessão expirada. Faça login novamente."}), 401


def _registrar_cli(app: Flask):
    @app.cli.command("seed")
    @click.option("--forcar", is_flag=True, help="Semeia mesmo que já exista.")
    def seed_cmd(forcar):
        from .seed import semear

        click.echo("Seed criado." if semear(forcar) else "Seed já existia; nada feito.")

    @app.cli.command("reset-db")
    @click.confirmation_option(prompt="Isto APAGA todos os dados do banco. Continuar?")
    def reset_db():
        """Apaga todos os dados e recria o banco só com o seed."""
        if _usa_sqlite(app):
            db.drop_all()
            db.create_all()
        else:
            from flask_migrate import downgrade, upgrade

            downgrade(revision="base")
            upgrade()
        from .seed import semear

        semear(forcar=True)
        click.echo("Banco recriado com seed.")
