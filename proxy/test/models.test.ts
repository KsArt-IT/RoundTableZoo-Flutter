import { describe, expect, it } from "vitest";
import { selectModel } from "../src/models";

describe("selectModel — приоритет, не round-robin (FR-007a, research.md R19)", () => {
  it("выбирает первую модель, если её счётчик в пределах капа", async () => {
    const seen: string[] = [];
    const result = await selectModel(["primary", "fallback"], 400, async (model) => {
      seen.push(model);
      return 1;
    });
    expect(result).toEqual({ ok: true, model: "primary" });
    expect(seen).toEqual(["primary"]);
  });

  it("переключается на резервную модель, если основная исчерпана", async () => {
    const result = await selectModel(["primary", "fallback"], 400, async (model) =>
      model === "primary" ? 401 : 1,
    );
    expect(result).toEqual({ ok: true, model: "fallback" });
  });

  it("список исчерпан => ok:false", async () => {
    const result = await selectModel(["primary", "fallback"], 400, async () => 999);
    expect(result).toEqual({ ok: false });
  });

  it("не применяет чередование — повторный вызов с тем же состоянием даёт ту же модель", async () => {
    const increment = async (model: string) => (model === "primary" ? 1 : 1);
    const first = await selectModel(["primary", "fallback"], 400, increment);
    const second = await selectModel(["primary", "fallback"], 400, increment);
    expect(first).toEqual({ ok: true, model: "primary" });
    expect(second).toEqual({ ok: true, model: "primary" });
  });
});
