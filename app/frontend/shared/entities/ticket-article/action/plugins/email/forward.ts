// Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

import { getArticleAttachmentsLinks } from '@shared/entities/ticket-article/composables/getArticleAttachmentsLinks'
import { useTicketArticleEmailForwardReplyMutation } from '@shared/entities/ticket-article/graphql/mutations/ticketArticleEmailForwardReply.api'
import type { TicketArticle, TicketById } from '@shared/entities/ticket/types'
import type { TicketArticleEmailForwardReplyMutation } from '@shared/graphql/types'
import { i18n } from '@shared/i18n'
import { MutationHandler } from '@shared/server/apollo/handler'
import type { ConfigList } from '@shared/types/store'
import type { ConfidentTake } from '@shared/types/utils'
import { textCleanup, textToHtml } from '@shared/utils/helpers'
import type { TicketArticlePerformOptions } from '../types'

const forwardMutation = new MutationHandler(
  useTicketArticleEmailForwardReplyMutation({}),
  { errorShowNotification: true },
)

export const buildEmailForwardHeader = (
  article: TicketArticle,
  meta: ConfidentTake<
    TicketArticleEmailForwardReplyMutation,
    'ticketArticleEmailForwardReply'
  >,
) => {
  const { quotableFrom, quotableCc, quotableTo } = meta || {}

  const fields = [
    [__('Subject'), article.subject],
    [__('Date'), i18n.dateTime(article.createdAt)],
    [__('From'), quotableFrom],
    [__('To'), quotableTo],
    [__('CC'), quotableCc],
  ] as const

  const output = fields.reduce((acc, [key, value]) => {
    if (value) {
      acc.append(i18n.t(key), ': ', value, document.createElement('br'))
    }
    return acc
  }, document.createElement('p'))

  output.appendChild(document.createElement('br'))

  return output.outerHTML
}

export const forwardEmail = async (
  ticket: TicketById,
  article: TicketArticle,
  options: TicketArticlePerformOptions,
  config: ConfigList,
) => {
  let body =
    article.contentType === 'text/html'
      ? textCleanup(article.bodyWithUrls)
      : textToHtml(textCleanup(article.bodyWithUrls))

  // TODO: standardise this in https://github.com/zammad/coordination-feature-mobile-view/issues/396
  body = body.replace(/<p><br><\/p>/g, '<p></p>') // cleanup

  const result = await forwardMutation
    .send({
      formId: options.formId,
      articleId: article.id,
    })
    .then((r) => r?.ticketArticleEmailForwardReply)

  // show attachment previews, but don't save its content
  const attachments = (result?.attachments || []).map((file, idx) => {
    const originalAttachment = article.attachmentsWithoutInline[idx]
    if (!originalAttachment || originalAttachment.name !== file.name)
      return file
    const { previewUrl, inlineUrl } = getArticleAttachmentsLinks(
      {
        ticketInternalId: ticket.internalId,
        articleInternalId: article.internalId,
        internalId: originalAttachment.internalId,
        type: file.type,
      },
      config,
    )
    return {
      ...file,
      preview: previewUrl,
      inline: inlineUrl,
    }
  })
  const quotedHeader =
    config.ui_ticket_zoom_article_email_full_quote_header && result
      ? buildEmailForwardHeader(article, result)
      : ''

  const quotedBody = `<p data-marker="signature-before"></p><p>---${i18n.t(
    'Begin forwarded message',
  )}:---</p><p></p><blockquote type="cite">${quotedHeader}${body}</blockquote>`

  return options.openReplyDialog({
    articleType: 'email',
    subject: config.ui_ticket_zoom_article_email_subject
      ? article.subject || ticket.title
      : '',
    subtype: 'forward',
    attachments,
    body: quotedBody,
  })
}
