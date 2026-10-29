# Anuncio de MirloTalk (Remotion, D-056)

Vídeo vertical 1080×1920 de ~44 s, en español. Lo cuenta una estudiante con una voz de OpenAI (`gpt-4o-mini-tts`, voz `marin`). Los subtítulos están siempre en pantalla y la palabra que se dice resplandece; sus tiempos salen de Whisper.

```bash
cd speaking-p2p/marketing/ad
npm install
# 1) Guion: scripts/script.mjs (una frase por escena; el tono, en INSTRUCTIONS).
# 2) Voz + tiempos por palabra (lee OPENAI_API_KEY de speaking-p2p/.env; ~0,02 $):
node scripts/openai-voice.mjs samples         # 3 muestras en out/samples/ para elegir voz
node scripts/openai-voice.mjs render marin    # public/vo/line<n>.wav + src/timing.json
node scripts/openai-voice.mjs retime          # solo vuelve a sacar los tiempos (sin pagar la voz)
# 3) Previsualizar y exportar:
npm run studio
npm run render        # -> out/mirlotalk-anuncio.mp4
```

- **Gasto:** cada llamada queda apuntada en `.openai-spend.json` (fuera de git), con un tope de 0,5 $ en el script.
- **Capturas:** son las reales de la app en español y modo oscuro (`docs/screenshots/*-oscuro.png`), recortadas a `public/screens/`, cada una de 786×1702.
- **Maquetación:** titular arriba, imagen en el centro y subtítulos abajo, todo centrado y con el mismo margen (80 px) a los dos lados.
- **Marca:** sin logos ni nombres de examen de Cambridge; al final aparece el aviso de no afiliación.
- **Remotion:** licencia gratuita para particulares y empresas de hasta 3 personas.
