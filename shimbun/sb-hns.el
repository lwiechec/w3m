;;; sb-hns.el --- shimbun backend for Hyper Nikki System.
;;
;; Copyright (C) 2001 Yuuichi Teranishi <teranisi@gohome.org>

;; Author: Yuuichi Teranishi <teranisi@gohome.org>
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

(eval-and-compile
  (luna-define-class shimbun-hns (shimbun) (content-hash))
  (luna-define-internal-accessors 'shimbun-hns))

(defvar shimbun-hns-group-alist nil
  "An alist of HNS shimbun group definition.
Each element looks like (NAME URL ADDRESS X-FACE).
NAME is a shimbun group name.
URL is the URL for HNS access point of the group.
ADDRESS is the e-mail address for the diary owner.
Optional X-FACE is a string for X-Face field.
It can be defined in the `shimbun-hns-x-face-alist', too.
(X-FACE in this definition precedes `shimbun-hns-x-face-alist' entry).")

(defvar shimbun-hns-content-hash-length 31)

(defvar shimbun-hns-x-face-alist
  '(("default" . "X-Face: @a`mMVT%~3Um4-$Sx\\K<}C%MwIx/g]o(Z:3qR\
3BsyZ_Bp@;$m~@,]+*=`@Y$4754xsoPo~/\n eJSA]x(_m@-BmURu#F8nZm'M4!v\
X$a3`)e}~`]8^'3^3s/gg+]|xf}gg2[BZZAR)-5pOF6BgPu(%yx\n At\\)Z\"e,\
V#i5>7]N{lif*16&rrh3=:)\"dB[w:{_Mu@7+)~qLo6.z&Bb|Gq0A1}xpj:>9o9$")))


(luna-define-method initialize-instance :after ((shimbun shimbun-hns)
						&rest init-args)
  (shimbun-hns-set-content-hash-internal
   shimbun
   (make-vector shimbun-hns-content-hash-length 0))
  shimbun)

(luna-define-method shimbun-groups ((shimbun shimbun-hns))
  (mapcar 'car shimbun-hns-group-alist))

(luna-define-method shimbun-index-url ((shimbun shimbun-hns))
  (concat (cadr (assoc (shimbun-current-group-internal shimbun)
		       shimbun-hns-group-alist))
	  "title.cgi"))

(luna-define-method shimbun-get-headers ((shimbun shimbun-hns)
					 &optional range)
  (let ((case-fold-search t)
	id year month mday sect uniq xref pos subject
	headers)
    (goto-char (point-min))
    (while (re-search-forward "<a href=\"\\([^<\\#]*#\\(\\([0-9][0-9][0-9][0-9]\\)\\([0-9][0-9]\\)\\([0-9][0-9]\\)\\([0-9]+\\)\\)\\)\">[^<]+</a>:" nil t)
      (setq year  (string-to-number (match-string 3))
	    month (string-to-number (match-string 4))
	    mday  (string-to-number (match-string 5))
	    sect  (string-to-number (match-string 6))
	    uniq  (match-string 2)
	    xref  (shimbun-expand-url
		   (match-string 1)
		   (cadr (assoc (shimbun-current-group-internal shimbun)
				shimbun-hns-group-alist)))
	    pos (point))
      (when (re-search-forward "<br>" nil t)
	(setq subject (buffer-substring pos (match-beginning 0))
	      subject (with-temp-buffer
			(insert subject)
			(goto-char (point-min))
			(if (re-search-forward "[ \t\n]*" nil t)
			    (delete-region (point-min) (point)))
			(shimbun-remove-markup)
			(buffer-string))))
      (setq id (format "<%s%%%s.hns>" uniq
		       ;; Sometimes include kanji.
		       (eword-encode-string
			(shimbun-current-group-internal
			 shimbun))))
      (push (shimbun-make-header
	     0
	     (shimbun-mime-encode-string (or subject ""))
	     (nth 2 (assoc (shimbun-current-group-internal shimbun)
			   shimbun-hns-group-alist))
	     (shimbun-make-date-string year month mday
				       (format "00:%02d" sect))
	     id "" 0 0 xref)
	    headers))
    headers))
;    ;; sort by xref
;    (sort headers (lambda (a b) (string< (shimbun-header-xref a)
;					 (shimbun-header-xref b))))))

(defun shimbun-hns-article (shimbun xref)
  "Return article string which corresponds to SHIMBUN and XREF."
  (let (uniq start sym)
    (when (string-match "#" xref)
      (setq uniq (substring xref (match-end 0)))
      (if (boundp (setq sym (intern uniq
				    (shimbun-hns-content-hash-internal
				     shimbun))))
	  (symbol-value sym)
	(with-current-buffer (shimbun-retrieve-url-buffer xref 'reload)
	  ;; Add articles to the content hash.
	  (goto-char (point-min))
	  (while (re-search-forward
		  "<h3 class=\"new\"><a [^<]*name=\"\\([0-9]+\\)\"" nil t)
	    (let ((id (match-string 1)))
	      (when (re-search-forward "</a>" nil t)
		(setq start (point))
		(when (re-search-forward "<!-- end of R?L?NEW -->" nil t)
		  (set (intern id (shimbun-hns-content-hash-internal shimbun))
		       (concat "<h3>" (buffer-substring start (point))))))))
	  (if (boundp (setq sym (intern-soft uniq
					     (shimbun-hns-content-hash-internal
					      shimbun))))
	      (symbol-value sym)))))))

(luna-define-method shimbun-x-face ((shimbun shimbun-hns))
  (or (shimbun-x-face-internal shimbun)
      (shimbun-set-x-face-internal
       shimbun
       (or
	(nth 3 (assoc (shimbun-current-group-internal shimbun)
		      shimbun-hns-group-alist))
	(cdr (assoc (shimbun-current-group-internal shimbun)
		    (shimbun-x-face-alist-internal shimbun)))
	(cdr (assoc "default" (shimbun-x-face-alist-internal shimbun)))
	shimbun-x-face))))

(luna-define-method shimbun-article ((shimbun shimbun-hns) header
				     &optional outbuf)
  (when (shimbun-current-group-internal shimbun)
    (with-current-buffer (or outbuf (current-buffer))
      (insert
       (with-temp-buffer
	 (insert (or (shimbun-hns-article shimbun (shimbun-header-xref header))
		     ""))
	 (shimbun-make-mime-article shimbun header)
	 (buffer-string))))))

(luna-define-method shimbun-close :after ((shimbun shimbun-hns))
  (shimbun-hns-set-content-hash-internal shimbun nil))

(provide 'sb-hns)

;;; sb-hns.el ends here
