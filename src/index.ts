import { Telegraf } from 'telegraf'
import makeHandler from 'lambda-request-handler'
import { config } from './config'
import * as manga from './manga'
import * as email from './email'
import * as download from './download'
import * as pdf from './pdf'
import * as zip from './zip'
import { format } from 'util'

import d from 'debug'
const debug = d('mtk:index');

const bot = new Telegraf(config.bot.token, {
  telegram: { webhookReply: true }
});

bot.hears(manga.chapterURLRegex, async (ctx) => {
    // Get manga info
    debug("Mangadex chapter link detected");
    const chapterId = parseInt(ctx.match[1], 10);
    const info = await manga.getMangaInfo(chapterId);
    const baseFilename = info.mangaName;
    const pdfFilename = `${baseFilename}.pdf`;
    const zipFilename = `${baseFilename}.zip`;
    debug("Got manga info");

    const pageBuffs = await download.downloadPages(info.pageLinks);
    debug("Got pages");
    const pdfStream = await pdf.buildPDF(pageBuffs);
    debug("Got build pdf");

    const zipStream = await zip.zipStream(pdfStream, pdfFilename);
    debug("Got zip");

    await email.emailMangaPDF(zipStream, zipFilename);

    debug("Replying to message with confirmation");
    ctx.reply(format("Successfully packaged and sent %s", zipFilename));
});

bot.on('text', async (ctx) => {
    ctx.reply(`Did not recognise '${ctx.message.text}'`);
});

bot.catch(async (err, ctx) => {
    debug("Telegraf caught error, reporting to user %s", err);
    ctx.reply(`Failed with error: ${err}`)
});

export const handler = makeHandler(
    bot.webhookCallback(config.bot.hook_path)
);
