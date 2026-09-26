# VPS Caseira

Servidor pessoal rodando no PC de casa (WSL2 + Apache + Cloudflare Tunnel), com deploy automático via GitHub Actions (self-hosted runner).

## Estrutura

- `index.html` — página inicial do VPS
- `projetos/` — cada projeto novo vira uma subpasta aqui, por exemplo `projetos/meu-projeto/index.html`
- `.htaccess` — protege o site com login (usuário e senha)
- `.github/workflows/deploy.yml` — copia os arquivos para `/var/www/html` no PC servidor a cada push

## Como criar um projeto novo

1. Crie uma pasta dentro de `projetos/`, por exemplo `projetos/meu-projeto/`
2. Coloque os arquivos do projeto lá dentro (`index.html`, etc.)
3. Faça commit e push — o deploy automático cuida do resto
4. Acesse em `http://topachadinhos.com.br/projetos/meu-projeto/`

## Atualizar manualmente no PC servidor (se precisar)

```bash
cd /var/www/html
git pull
```
