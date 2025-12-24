package main

import (
	"fmt"
	"io"
	"time"
)

// MakeMKV output attribute IDs
const (
	// CINFO attributes
	AttrType      = 1  // Media type (e.g., "Blu-ray disc")
	AttrName      = 2  // Disc name
	AttrLangCode  = 3  // Language code
	AttrLangName  = 4  // Language name
	AttrTreeInfo  = 28 // Tree info
	AttrPanelTitle = 30 // Panel title (same as name usually)
	AttrVolumeName = 32 // Volume name / disc ID

	// TINFO attributes
	AttrTitleName   = 2  // Title name
	AttrChapterCount = 8 // Number of chapters
	AttrDuration    = 9  // Duration string
	AttrSize        = 10 // Size string
	AttrSegmentCount = 11 // Number of segments
	AttrSegmentMap  = 16 // Segment map
	AttrFilename    = 27 // Output filename
)

// OutputWriter generates makemkvcon-compatible output
type OutputWriter struct {
	w io.Writer
}

// NewOutputWriter creates a new output writer
func NewOutputWriter(w io.Writer) *OutputWriter {
	return &OutputWriter{w: w}
}

// WriteDRV outputs a drive information line
// Format: DRV:index,visible,enabled,flags,"device_name","disc_name"
func (o *OutputWriter) WriteDRV(index int, deviceName, discName string) {
	fmt.Fprintf(o.w, "DRV:%d,2,999,1,%q,%q\n", index, deviceName, discName)
}

// WriteCINFO outputs a disc info line
// Format: CINFO:id,code,"value"
func (o *OutputWriter) WriteCINFO(id, code int, value string) {
	fmt.Fprintf(o.w, "CINFO:%d,%d,%q\n", id, code, value)
}

// WriteTCOUT outputs the title count
// Format: TCOUT:count
func (o *OutputWriter) WriteTCOUT(count int) {
	fmt.Fprintf(o.w, "TCOUT:%d\n", count)
}

// WriteTINFO outputs a title info line
// Format: TINFO:titleIdx,attrId,code,"value"
func (o *OutputWriter) WriteTINFO(titleIdx, attrId, code int, value string) {
	fmt.Fprintf(o.w, "TINFO:%d,%d,%d,%q\n", titleIdx, attrId, code, value)
}

// WriteSINFO outputs a stream info line
// Format: SINFO:titleIdx,streamIdx,attrId,code,"value"
func (o *OutputWriter) WriteSINFO(titleIdx, streamIdx, attrId, code int, value string) {
	fmt.Fprintf(o.w, "SINFO:%d,%d,%d,%d,%q\n", titleIdx, streamIdx, attrId, code, value)
}

// WritePRGV outputs a progress line
// Format: PRGV:current,total,max
func (o *OutputWriter) WritePRGV(current, total, max int) {
	fmt.Fprintf(o.w, "PRGV:%d,%d,%d\n", current, total, max)
}

// WritePRGT outputs a progress title line
// Format: PRGT:code,"message","format","params..."
func (o *OutputWriter) WritePRGT(code int, message string) {
	fmt.Fprintf(o.w, "PRGT:%d,0,%q\n", code, message)
}

// WritePRGC outputs a progress current item line
// Format: PRGC:code,"message"
func (o *OutputWriter) WritePRGC(code int, message string) {
	fmt.Fprintf(o.w, "PRGC:%d,0,%q\n", code, message)
}

// WriteMSG outputs a message line
// Format: MSG:code,flags,count,"message","format","params..."
func (o *OutputWriter) WriteMSG(code int, message string) {
	fmt.Fprintf(o.w, "MSG:%d,0,0,%q,%q\n", code, message, message)
}

// WriteDiscInfo outputs all disc information for a profile
func (o *OutputWriter) WriteDiscInfo(profile *DiscProfile) {
	// Write MSG for startup
	o.WriteMSG(1005, "MakeMKV v1.17.6 (mock) started")

	// Write drive info
	o.WriteDRV(0, "BD-ROM Mock Drive", profile.DiscTitle)

	// Write disc info
	o.WriteCINFO(AttrType, 6209, "Blu-ray disc")
	o.WriteCINFO(AttrName, 0, profile.DiscTitle)
	o.WriteCINFO(AttrPanelTitle, 0, profile.DiscTitle)
	o.WriteCINFO(AttrVolumeName, 0, profile.DiscID)

	// Write title count
	o.WriteTCOUT(len(profile.Titles))

	// Write info for each title
	for _, title := range profile.Titles {
		o.WriteTINFO(title.Index, AttrTitleName, 0, title.Name)
		o.WriteTINFO(title.Index, AttrDuration, 0, FormatDuration(title.Duration))
		o.WriteTINFO(title.Index, AttrSize, 0, FormatSize(title.Size))
		o.WriteTINFO(title.Index, AttrFilename, 0, title.Filename)
	}
}

// WriteRipProgress outputs progress for ripping titles
func (o *OutputWriter) WriteRipProgress(titleIdx int, title *TitleInfo, progressPercent float64, delay time.Duration) {
	max := 65536
	current := int(progressPercent / 100.0 * float64(max))

	o.WritePRGT(5021, fmt.Sprintf("Saving title %d", titleIdx))
	o.WritePRGC(5022, title.Filename)
	o.WritePRGV(current, 0, max)

	if delay > 0 {
		time.Sleep(delay)
	}
}

// FormatDuration formats a duration as H:MM:SS
func FormatDuration(d time.Duration) string {
	hours := int(d.Hours())
	minutes := int(d.Minutes()) % 60
	seconds := int(d.Seconds()) % 60
	return fmt.Sprintf("%d:%02d:%02d", hours, minutes, seconds)
}

// FormatSize formats a size in bytes as a human-readable string
func FormatSize(size int64) string {
	const (
		KB = 1024
		MB = 1024 * KB
		GB = 1024 * MB
	)

	switch {
	case size >= GB:
		return fmt.Sprintf("%.1f GB", float64(size)/float64(GB))
	case size >= MB:
		return fmt.Sprintf("%.1f MB", float64(size)/float64(MB))
	case size >= KB:
		return fmt.Sprintf("%d KB", size/KB)
	default:
		return fmt.Sprintf("%d B", size)
	}
}
