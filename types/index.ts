type Prettify<T> = {
	[K in keyof T]: T[K];
} & {};

interface Hadith {
	id: number;
	idInBook: number;
	arabic: string;
	english: {
		narrator: string;
		text: string;
	};
	chapterId: number;
	bookId: number;
	/** Optional authenticity grade (ported from muallimai/hadith-json). */
	grade?: string | null;
	/** Optional sunnah.com-style reference (ported from muallimai/hadith-json). */
	reference?: {
		text?: string;
		url?: string;
	};
}

interface Introduction {
	arabic: string;
	english: string;
}

interface Chapter {
	id: number;
	bookId: number;
	arabic: string;
	english: string;
}

interface BookInfo {
	title: string;
	author: string;
	introduction: string | undefined;
}

interface Metadata {
	length: number;
	arabic: Prettify<BookInfo>;
	english: Prettify<BookInfo>;
}

interface ChapterFile {
	metadata: Prettify<Metadata>;
	hadiths: Hadith[];
	chapter: Chapter | undefined;
}

interface BookMetadata extends Metadata {
	id: number;
}

interface BookFile {
	id: number;
	metadata: Prettify<BookMetadata>;
	chapters: Chapter[];
	hadiths: Hadith[];
}

interface ScrapedBook {
	id: number;
	arabic: {
		title: string;
		author: string;
	};
	english: {
		title: string;
		author: string;
	};
	length?: number;
	path: string[];
	route: {
		base: string;
		chapters: string[];
	};
}

/** Per-locale draft translations (see db/by_locale; Indonesian ported from sagad/hadith-json). */
type Locale = "ar" | "en" | "id";
type TranslationStatus = "source" | "missing" | "draft" | "verified";

interface LocalizedHadith {
	id: number;
	idInBook: number;
	chapterId: number;
	bookId: number;
	translation: {
		text: string;
		narrator?: string;
		status: TranslationStatus;
	};
}