/* $Id: UIVMLogViewerTextEdit.h $ */
/** @file
 * VBox Qt GUI - UIVMLogViewer class declaration.
 */

/*
 * Copyright (C) 2010-2022 Oracle and/or its affiliates.
 *
 * This file is part of VirtualBox base platform packages, as
 * available from https://www.virtualbox.org.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation, in version 3 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <https://www.gnu.org/licenses>.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

#ifndef FEQT_INCLUDED_SRC_logviewer_UIVMLogViewerTextEdit_h
#define FEQT_INCLUDED_SRC_logviewer_UIVMLogViewerTextEdit_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

/* GUI includes: */
#include "QIWithRetranslateUI.h"

/* Qt includes: */
#include <QPlainTextEdit>
#include <QPair>


/* QPlainTextEdit extension with some addtional context menu items,
   a special scrollbar, line number area, bookmarking support,
   background watermarking etc.: */
class UIVMLogViewerTextEdit : public QIWithRetranslateUI<QPlainTextEdit>
{
    Q_OBJECT;

signals:

    void sigAddBookmark(QPair<int, QString> bookmark);
    void sigDeleteBookmark(QPair<int, QString> bookmark);

public:

    UIVMLogViewerTextEdit(QWidget* parent = 0);

    int  lineNumberAreaWidth();
    void lineNumberAreaPaintEvent(QPaintEvent *event);
    /** Forwards the call to scroll bar class */
    void setScrollBarMarkingsVector(const QVector<float> &vector);
    /** Forwards the call to scroll bar class */
    void clearScrollBarMarkingsVector();

    void scrollToLine(int lineNumber);
    void scrollToEnd();
    void setBookmarkLineSet(const QSet<int>& lineSet);
    void setShownTextIsFiltered(bool warning);

    void setShowLineNumbers(bool bShowLineNumbers);
    bool showLineNumbers() const;

    void setWrapLines(bool bWrapLines);
    bool wrapLines() const;

    /** currentVerticalScrollBarValue is used by UIVMLogPage to store and restore scrolled
        plain text position as we switch from a tab to another */
    int  currentVerticalScrollBarValue() const;
    void setCurrentVerticalScrollBarValue(int value);
    void setCurrentFont(QFont font);

protected:

    virtual void contextMenuEvent(QContextMenuEvent *pEvent) RT_OVERRIDE;
    virtual void resizeEvent(QResizeEvent *pEvent) RT_OVERRIDE;
    virtual void mouseMoveEvent(QMouseEvent *pEvent) RT_OVERRIDE;
    virtual void leaveEvent(QEvent * pEvent) RT_OVERRIDE;
    virtual void retranslateUi() RT_OVERRIDE;

private slots:

    void sltBookmark();
    void sltUpdateLineNumberAreaWidth(int newBlockCount);
    void sltHandleUpdateRequest(const QRect &, int);
    int  visibleLineCount();

private:

    /** Configures this (such as palette etc.) */
    void configure();
    void prepare();
    void prepareWidgets();
    QPair<int, QString> bookmarkForPos(const QPoint &position);
    int  lineNumberForPos(const QPoint &position);
    void setMouseCursorLine(int lineNumber);
    /** If bookmark exists this function removes it, if not it adds the bookmark. */
    void toggleBookmark(const QPair<int, QString>& bookmark);

    /** Line number and text at the context menu position */
    QPair<int, QString>  m_iContextMenuBookmark;
    QWidget             *m_pLineNumberArea;
    /** Set of bookmarked lines. This set is updated from UIVMLogPage. This set is
        used only for lookup in this class. */
    QSet<int>            m_bookmarkLineSet;
    /** Number of the line under the mouse cursor. */
    int                  m_mouseCursorLine;
    /** If true the we draw a text near the top right corner of the text edit to warn
        the user the text edit's content is filtered (as oppesed to whole log file content.
        And we dont display bookmarks and adding/deleting bookmarks are disabled. */
    bool         m_bShownTextIsFiltered;
    bool         m_bShowLineNumbers;
    bool         m_bWrapLines;
    QString      m_strBackgroungText;
    friend class UILineNumberArea;
    bool         m_bHasContextMenu;
 };




#endif /* !FEQT_INCLUDED_SRC_logviewer_UIVMLogViewerTextEdit_h */
