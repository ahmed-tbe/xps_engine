import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const projectDir = process.cwd();
const packageDir = path.join(projectDir, "results", "phase0h_scientific_conclusions_v1_0_0");
const outputPath = path.join(packageDir, "Phase_0H_Scientific_Conclusions_v1.0.0.xlsx");
const previewDir = path.join(packageDir, "_workbook_previews");
const fontFamily = "Arial";

function parseCsv(text) {
  const rows = [];
  let row = [], field = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { row.push(field); field = ""; }
    else if (ch === '\n') {
      row.push(field.replace(/\r$/, ""));
      rows.push(row); row = []; field = "";
    } else field += ch;
  }
  if (field.length || row.length) { row.push(field.replace(/\r$/, "")); rows.push(row); }
  return rows.filter(r => !(r.length === 1 && r[0] === ""));
}

function typedValue(header, raw) {
  if (raw === "") return null;
  if (raw === "NaN") return "N/A";
  if (/^(true|false)$/i.test(raw)) return raw.toLowerCase() === "true";
  const textHeader = /^(CellKey|CellIDs|FamilyName|ModelID|Scenario|Gate|GateStatus|PrimaryFailureReasons|Model1ThresholdAssessment|Model2ThresholdAssessment|FailureCategory|CategoryType|Interpretation|BaseProfile|SourceRunID|SourceExecutionFingerprint|Issue|Evidence|RecommendedABInvestigation)$/i.test(header);
  if (!textHeader && /^[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?$/.test(raw)) return Number(raw);
  return raw;
}

async function loadCsv(fileName) {
  const text = await fs.readFile(path.join(packageDir, fileName), "utf8");
  const raw = parseCsv(text.replace(/^\uFEFF/, ""));
  const headers = raw[0];
  const rows = raw.slice(1).map(r => headers.map((h, i) => typedValue(h, r[i] ?? "")));
  return { headers, rows };
}

function columnLetter(index) {
  let n = index + 1, out = "";
  while (n) { n--; out = String.fromCharCode(65 + (n % 26)) + out; n = Math.floor(n / 26); }
  return out;
}

function styleTitle(sheet, title, subtitle) {
  sheet.showGridLines = false;
  sheet.getRange("A2").values = [[title]];
  sheet.getRange("A2").format.font = { name: fontFamily, size: 15, bold: true, color: "#172554" };
  sheet.getRange("A3").values = [[subtitle]];
  sheet.getRange("A3").format.font = { name: fontFamily, size: 10, italic: true, color: "#475569" };
}

function setColumnFormats(sheet, headers, startRow, rowCount) {
  for (let c = 0; c < headers.length; c++) {
    const h = headers[c];
    const body = sheet.getRangeByIndexes(startRow, c, rowCount, 1);
    if (/(Rate|Withheld|Error_rel|Difference_rel)$/i.test(h)) body.setNumberFormat("0.00%");
    else if (/(R2)$/i.test(h)) body.setNumberFormat("0.0000");
    else if (/(RMSE|_eV|_pp|FAt|F_over_C|S_F|Multiplier)/i.test(h)) body.setNumberFormat("0.000");
    else if (/(^N|Count|Cells|Trials|FamilyID|FinalN)$/i.test(h)) body.setNumberFormat("#,##0");
  }
}

function fitColumns(sheet, headers, rows, totalRows) {
  for (let c = 0; c < headers.length; c++) {
    let width = Math.max(10, Math.min(22, headers[c].length + 2));
    for (let r = 0; r < Math.min(rows.length, 40); r++) {
      const s = rows[r][c] == null ? "" : String(rows[r][c]);
      width = Math.max(width, Math.min(34, s.length + 2));
    }
    if (/(Scenario|Reason|Interpretation|Evidence|Recommended)/i.test(headers[c])) width = 38;
    sheet.getRangeByIndexes(0, c, totalRows, 1).format.columnWidth = width;
  }
}

function addStatusFormatting(sheet, headers, rowCount) {
  for (const name of ["GateStatus", "ThresholdAssessment"]) {
    const c = headers.indexOf(name);
    if (c < 0 || rowCount < 1) continue;
    const range = sheet.getRange(`${columnLetter(c)}5:${columnLetter(c)}${4 + rowCount}`);
    range.conditionalFormats.add("containsText", { text: "fail", format: { fill: "#FEE2E2", font: { color: "#991B1B", bold: true } } });
    range.conditionalFormats.add("containsText", { text: "pass", format: { fill: "#DCFCE7", font: { color: "#166534", bold: true } } });
    range.conditionalFormats.add("containsText", { text: "withheld", format: { fill: "#FEF3C7", font: { color: "#92400E", bold: true } } });
  }
}

function addDataSheet(workbook, sheetName, title, subtitle, data, sourceFile, tabColor) {
  const sheet = workbook.worksheets.add(sheetName);
  sheet.tabColor = tabColor;
  styleTitle(sheet, title, subtitle);
  const matrix = [data.headers, ...data.rows];
  const endCol = columnLetter(data.headers.length - 1);
  const endRow = 4 + data.rows.length;
  sheet.getRange(`A4:${endCol}${endRow}`).values = matrix;
  sheet.getRange(`A4:${endCol}4`).format = {
    fill: "#1E3A5F",
    font: { name: fontFamily, size: 10, bold: true, color: "#FFFFFF" },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "outside", style: "thin", color: "#1E3A5F" },
  };
  if (data.rows.length) {
    const body = sheet.getRange(`A5:${endCol}${endRow}`);
    body.format.font = { name: fontFamily, size: 10, color: "#1F2937" };
    body.format.verticalAlignment = "center";
    body.format.borders = { insideHorizontal: { style: "thin", color: "#E5E7EB" } };
    setColumnFormats(sheet, data.headers, 4, data.rows.length);
    addStatusFormatting(sheet, data.headers, data.rows.length);
  }
  fitColumns(sheet, data.headers, data.rows, endRow + 3);
  sheet.getRange(`A${endRow + 2}`).values = [[`Source: ${path.join(packageDir, sourceFile)}`]];
  sheet.getRange(`A${endRow + 2}`).format.font = { name: fontFamily, size: 9, italic: true, color: "#64748B" };
  sheet.freezePanes.freezeRows(4);
  if (data.headers.length > 8) sheet.freezePanes.freezeColumns(Math.min(3, data.headers.length));
  return sheet;
}

const [gate, models, families, cells, failures, model1, model2, qc, sf, priorities] = await Promise.all([
  loadCsv("gate_overview.csv"), loadCsv("model_comparison.csv"), loadCsv("family_summary.csv"),
  loadCsv("per_cell_summary.csv"), loadCsv("gate_failure_decomposition.csv"),
  loadCsv("model1_robustness.csv"), loadCsv("model2_robustness.csv"),
  loadCsv("qc_false_valid_false_invalid.csv"), loadCsv("sensitivity_factor_sweep.csv"),
  loadCsv("sample_AB_investigation_priorities.csv"),
]);

const workbook = Workbook.create();
const exec = workbook.worksheets.add("Executive summary");
exec.tabColor = "#172554";
styleTitle(exec, "Phase 0H scientific conclusions", "Frozen final analysis: 92 cells, 21,800 usable trials; Sample C unused");
exec.getRange("A5:C5").values = [["Metric", "Value", "Interpretation"]];
exec.getRange("A6:C13").values = [
  ["Cells", 92, "All planned cells represented"],
  ["Usable trials", 21800, "42 cells at N=400; 50 cells at N=100"],
  ["Converged trials", 21799, "One scientific nonconvergence retained"],
  ["Gate A", "0 pass / 11 fail", "Whole-pipeline nominal/in-model gate"],
  ["Gate B", "0 pass / 20 fail", "Whole-pipeline misspecified/stress gate"],
  ["Gate C", "22 pass / 23 fail", "Safety/withholding behavior"],
  ["Order", "1 pass / 0 fail", "Paired order criterion passed"],
  ["Scale", "2 pass / 2 fail", "Two exact scale controls failed through QC withholding"],
];
exec.getRange("E5:H5").values = [["Gate class", "Pass", "Fail", "Descriptive"]];
exec.getRange("E6:H13").values = gate.rows.map(r => [r[0], r[3], r[4], r[5]]);
exec.getRange("A16:F16").values = [["Model", "A/B meets", "A/B fails", "A/B fully withheld", "Worst P95 F/C error", "Worst P95 F-at. error (pp)"]];
exec.getRange("A17:F18").values = models.rows.map(r => [r[0], r[2], r[3], r[4], r[10], r[12]]);
exec.getRange("A21:B21").values = [["Finding", "Interpretation"]];
exec.getRange("A22:B27").values = [
  ["Convergence", "21,799/21,800; numerical convergence does not establish chemical identifiability."],
  ["Peak recovery", "FWHM is the dominant strict-gate failure: 34 cells and 10,289/20,500 applicable trials."],
  ["Model 1", "Always available in A/B cells but fails assigned composition limits in 19/34 cells."],
  ["Model 2", "Meets assigned composition limits in 27/34 A/B cells, fails in 3, and fully withholds in 4."],
  ["QC", "22/45 Gate C cells pass; label mutations and acquisition-scale errors are safely rejected."],
  ["Development", "Investigate charging, peak shape, background, bounds, acquisition metadata, F_other, and substrate/shoulder structure on A/B only."],
];
for (const range of ["A5:C5", "E5:H5", "A16:F16", "A21:B21"]) {
  exec.getRange(range).format = { fill: "#1E3A5F", font: { name: fontFamily, size: 10, bold: true, color: "#FFFFFF" }, horizontalAlignment: "center", verticalAlignment: "center", wrapText: true };
}
exec.getRange("A6:H27").format.font = { name: fontFamily, size: 10, color: "#1F2937" };
for (const range of ["A5:C5", "E5:H5", "A16:F16", "A21:B21"]) {
  exec.getRange(range).format.font = { name: fontFamily, size: 10, bold: true, color: "#FFFFFF" };
}
exec.getRange("E6:G13").setNumberFormat("#,##0");
exec.getRange("B6:B8").setNumberFormat("#,##0");
exec.getRange("E6:H13").format.borders = { insideHorizontal: { style: "thin", color: "#E5E7EB" } };
exec.getRange("A6:C13").format.borders = { insideHorizontal: { style: "thin", color: "#E5E7EB" } };
exec.getRange("A17:F18").format.borders = { insideHorizontal: { style: "thin", color: "#E5E7EB" } };
exec.getRange("A22:B27").format.wrapText = true;
exec.getRange("A1:H30").format.verticalAlignment = "center";
exec.getRange("A1:A30").format.columnWidth = 28;
exec.getRange("B1:B30").format.columnWidth = 60;
exec.getRange("C1:C30").format.columnWidth = 36;
exec.getRange("E1:E30").format.columnWidth = 24;
exec.getRange("F1:H30").format.columnWidth = 14;

addDataSheet(workbook, "Model comparison", "Primary composition models", "Composition-only assessments; frozen whole-cell gates are unchanged", models, "model_comparison.csv", "#2563EB");
addDataSheet(workbook, "Family summary", "Stress-family summary", "All 16 predeclared Phase 0H stress families", families, "family_summary.csv", "#2563EB");
addDataSheet(workbook, "Per cell", "Complete per-cell results", "92 cells; N/A marks non-applicable quantities", cells, "per_cell_summary.csv", "#2563EB");
addDataSheet(workbook, "Gate failures", "Gate-failure decomposition", "Categories overlap; withholding may be protective", failures, "gate_failure_decomposition.csv", "#7C3AED");
addDataSheet(workbook, "Model 1", "Model 1 robustness", "ruoff_c1s_main_cf_v1", model1, "model1_robustness.csv", "#0F766E");
addDataSheet(workbook, "Model 2", "Model 2 robustness", "ruoff_c1s_f1s_semi_sf3p95_v1", model2, "model2_robustness.csv", "#0F766E");
addDataSheet(workbook, "QC rates", "Deployable QC classification", "Peak, composition, and overall false-valid/false-invalid rates are separate", qc, "qc_false_valid_false_invalid.csv", "#B45309");
addDataSheet(workbook, "SF sweep", "Sensitivity-factor sweep", "S_F profiles 3.95 and 4.118; descriptive systematic dependence", sf, "sensitivity_factor_sweep.csv", "#B45309");
addDataSheet(workbook, "A-B priorities", "Sample A/B investigation priorities", "Evidence-supported investigations only; no configuration changes", priorities, "sample_AB_investigation_priorities.csv", "#7C3AED");

const readme = workbook.worksheets.add("Read me");
readme.tabColor = "#64748B";
styleTitle(readme, "Provenance and interpretation notes", "Read-only conclusions package; no Monte Carlo execution");
readme.getRange("A5:B13").values = [
  ["Item", "Value"],
  ["Frozen source", path.join(projectDir, "results", "phase0h_final_v1_0_0", "phase0h_final_summary.mat")],
  ["Plan SHA-256", "1f932b278de41dc14154191833f45b5fcf55f3b5a01edd7a661ddcbcf2f556bf"],
  ["Summary SHA-256", "2d90e57a7fffd284597f521637c5e18c2bfee22d6e212206692c62a3bb7bf301"],
  ["Provenance SHA-256", "5b41766f2a30f4f44b17fb5cf9c70f9c71ff42c8bdcdc032cc0bae87fd62e9d7"],
  ["Post-processing SHA-256", "e4ea97b895ca78b955e1c57e684fa210695cad98f475b29ae7d5b7b741c48e18"],
  ["Sample C", "Not used; reserved for blind validation"],
  ["AICc/BIC", "Not used to rank different preprocessing/background families"],
  ["Rates", "Observed rates are primary gates; Wilson intervals are uncertainty only"],
];
readme.getRange("A5:B5").format = { fill: "#1E3A5F", font: { name: fontFamily, size: 10, bold: true, color: "#FFFFFF" }, horizontalAlignment: "center" };
readme.getRange("A6:B13").format.font = { name: fontFamily, size: 10, color: "#1F2937" };
readme.getRange("A6:B13").format.borders = { insideHorizontal: { style: "thin", color: "#E5E7EB" } };
readme.getRange("A1:A15").format.columnWidth = 28;
readme.getRange("B1:B15").format.columnWidth = 90;
readme.showGridLines = false;

await workbook.recalculate();

const summaryInspect = await workbook.inspect({ kind: "table", range: "Executive summary!A1:H27", include: "values,formulas", tableMaxRows: 30, tableMaxCols: 8, maxChars: 6000 });
console.log(summaryInspect.ndjson);
const cellInspect = await workbook.inspect({ kind: "table", range: "Per cell!A1:P12", include: "values,formulas", tableMaxRows: 12, tableMaxCols: 16, maxChars: 5000 });
console.log(cellInspect.ndjson);
const errorInspect = await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#NUM!|#NULL!|#SPILL!|#CALC!", options: { useRegex: true, maxResults: 300 }, summary: "final formula error scan", maxChars: 3000 });
console.log(errorInspect.ndjson);

await fs.mkdir(previewDir, { recursive: true });
const sheetNames = ["Executive summary", "Model comparison", "Family summary", "Per cell", "Gate failures", "Model 1", "Model 2", "QC rates", "SF sweep", "A-B priorities", "Read me"];
for (const sheetName of sheetNames) {
  const preview = await workbook.render({ sheetName, range: "A1:O25", scale: 1, format: "png" });
  const safe = sheetName.replace(/[^A-Za-z0-9]+/g, "_").toLowerCase();
  await fs.writeFile(path.join(previewDir, `${safe}.png`), new Uint8Array(await preview.arrayBuffer()));
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
console.log(`WORKBOOK_OUTPUT=${outputPath}`);
console.log(`PREVIEW_DIR=${previewDir}`);
