;;; sb-debian-jp.el --- shimbun backend for debian.or.jp

;; Copyright (C) 2001 OHASHI Akira <bg66@koka-in.org>

;; Author: OHASHI Akira <bg66@koka-in.org>
;; Keywords: news

;; This file is a part of shimbun.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, you can either send email to this
;; program's maintainer or write to: The Free Software Foundation,
;; Inc.; 59 Temple Place, Suite 330; Boston, MA 02111-1307, USA.

;;; Commentary:

;;; Code:

(require 'shimbun)
(require 'sb-mhonarc)

(luna-define-class shimbun-debian-jp (shimbun-mhonarc) ())

(defvar shimbun-debian-jp-url "http://lists.debian.or.jp/")
(defvar shimbun-debian-jp-groups
  '("debian-announce" "debian-devel" "debian-doc"
    "debian-www" "debian-users" "jp-policy" "jp-qa"))
(defvar shimbun-debian-jp-coding-system 'iso-2022-jp)
(defvar shimbun-debian-jp-reverse-flag nil)
(defvar shimbun-debian-jp-litemplate-regexp
  "<STRONG><A NAME=\"\\([0-9]+\\)\" HREF=\"\\(msg[0-9]+.html\\)\">\\([^<]+\\)</A></STRONG> <EM>\\([^<]+\\)</EM>")

(luna-define-method shimbun-index-url ((shimbun shimbun-debian-jp))
  (concat (shimbun-url-internal shimbun) 
	  (shimbun-current-group-internal shimbun) "/"))

(luna-define-method shimbun-reply-to ((shimbun shimbun-debian-jp))
  (concat (shimbun-current-group-internal shimbun) "@debian.or.jp"))

(luna-define-method shimbun-get-headers ((shimbun shimbun-debian-jp)
					 &optional range)
  (let ((case-fold-search t)
	(pages (shimbun-header-index-pages range))
	(count 0)
	headers months)
    (goto-char (point-min))
    (while (and (if pages (<= (incf count) pages) t)
		(re-search-forward "<A HREF=\"\\([0-9]+\\)/\">" nil t)
		(push (match-string 1) months)))
    (setq months (nreverse months))
    (erase-buffer)
    (catch 'stop
      (dolist (month months)
        (let ((url (concat (shimbun-index-url shimbun) month "/")))
	  (shimbun-retrieve-url url t)
	  (shimbun-mhonarc-get-headers shimbun url headers month))))
    headers))

(provide 'sb-debian-jp)

;;; sb-debian-jp.el ends here
