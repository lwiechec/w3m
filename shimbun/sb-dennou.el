;;; sb-dennou.el --- shimbun backend class for $BEEG>39$N8=>l%l%]!<%H(B web page. -*- coding: iso-2022-7bit; -*-

;; Copyright (C) 2003 NAKAJIMA Mikio <minakaji@namazu.org>

;; Author: NAKAJIMA Mikio <minakaji@namazu.org>
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

;;; Code:
(require 'shimbun)

(eval-and-compile
  (luna-define-class shimbun-dennou (shimbun) (content-hash))
  (luna-define-internal-accessors 'shimbun-dennou))

(defvar shimbun-dennou-content-hash-length 31)
(defvar shimbun-dennou-url "http://homepage1.nifty.com/akiba/plat.html")
(defvar shimbun-dennou-groups '("report"))
(defvar shimbun-dennou-coding-system 'shift_jis)

(defvar shimbun-dennou-expiration-days 6)

(luna-define-method initialize-instance :after ((shimbun shimbun-dennou)
						&rest init-args)
  (shimbun-dennou-set-content-hash-internal
   shimbun
   (make-vector shimbun-dennou-content-hash-length 0))
  shimbun)

(luna-define-method shimbun-index-url ((shimbun shimbun-dennou))
  shimbun-dennou-url)

(defun shimbun-dennou-make-date-string (month day)
  (shimbun-make-date-string
   (string-to-number (substring (current-time-string) 20))
   (string-to-number month)
   (string-to-number day)))

(luna-define-method shimbun-reply-to ((shimbun shimbun-dennou))
  "pc3s-nnb@asahi-net.or.jp")

(luna-define-method shimbun-headers ((shimbun shimbun-dennou)
				     &optional range)
  (let* ((case-fold-search t)
	 (url (shimbun-index-url shimbun))
	 (baseurl (and (string-match "\\(\.+/\\)[^/]+.html" url)
		       (match-string 1 url)))
	 month day subject date id start end body headers)
    (with-temp-buffer
      (shimbun-retrieve-url (shimbun-index-url shimbun) 'reload 'binary)
      (set-buffer-multibyte t)
      (decode-coding-region (point-min) (point-max)
			    (shimbun-coding-system-internal shimbun))
      (goto-char (point-min))
      (catch 'stop
	(while (re-search-forward "^<!-- *report start *-->" nil t nil)
	  ;; <td><b>$B"#(B2$B7n(B19$BF|!J?e!K(B $B$H$j$"$($:$N;n1?E>!%!%(B<font color="red">$B!ZDI2C99?7$"$j![(B</font></b></td>
	  (re-search-forward "<td><b>$B"#(B\\([0-9]+\\)$B7n(B\\([0-9]+\\)$BF|!J(B\\($B7n(B\\|$B2P(B\\|$B?e(B\\|$BLZ(B\\|$B6b(B\\|$BEZ(B\\|$BF|(B\\)$B!K(B\\(.+\\)</b></td>" nil t nil)
	  (setq month (match-string 1)
		day (match-string 2)
		subject (match-string 4)
		date (shimbun-dennou-make-date-string month day)
		;;id (format "<%02d%04d%02d%02d@dennou>"
		id (format "<%04d%02d%02d@dennou>"
			   (string-to-number
			    (substring (current-time-string) 20))
			   (string-to-number month)
			   (string-to-number day)))
	  (when (shimbun-search-id shimbun id)
	    (throw 'stop nil))
	  (with-temp-buffer
	    (insert subject)
	    (shimbun-remove-markup)
	    (setq subject (buffer-string)))
	  (setq start (point)
		end (re-search-forward "^<!-- *report end *-->" nil t nil))
	  (setq body (buffer-substring-no-properties start end))
	  (set (intern id (shimbun-dennou-content-hash-internal shimbun))
	       body)
	  (push (shimbun-make-header 0
				     (shimbun-mime-encode-string subject)
				     (shimbun-from-address shimbun)
				     date id "" 0 0 baseurl)
		headers)))
      (nreverse headers))))

(luna-define-method shimbun-article
  ((shimbun shimbun-dennou) header &optional outbuf)
  (let (string)
    (with-current-buffer (or outbuf (current-buffer))
      (with-temp-buffer
	(let ((sym (intern-soft (shimbun-header-id header)
				(shimbun-dennou-content-hash-internal
				 shimbun))))
	  (when (and (boundp sym) (symbol-value sym))
	    (insert (symbol-value sym))
	    (goto-char (point-min))
	    (insert "<html>\n<head>\n<base href=\""
		    (shimbun-header-xref header) "\">\n</head>\n<body>\n")
	    (goto-char (point-max))
	    (insert "\n</body>\n</html>\n")
	    (encode-coding-string
	     (buffer-string)
	     (mime-charset-to-coding-system "ISO-2022-JP"))
	    (shimbun-make-mime-article shimbun header)
	    (setq string (buffer-string)))))
      (when string
	(w3m-insert-string string)))))

(provide 'sb-dennou)

;;; sb-dennou.el ends here
